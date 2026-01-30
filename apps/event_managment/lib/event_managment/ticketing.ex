defmodule EventManagment.Ticketing do
  import Ecto.Query, warn: false

  alias EventManagment.Repo
  alias EventManagment.Events
  alias EventManagment.Ticketing.Order
  alias EventManagment.Payments.Gateway
  alias EventManagment.Workers.OrderConfirmationEmail

  @default_limit 50
  @max_limit 100

  def purchase_tickets(event_id, attrs) do
    case check_idempotency(attrs[:idempotency_key]) do
      {:ok, existing_order} -> {:ok, existing_order}
      :not_found -> do_purchase_tickets(event_id, attrs)
    end
  end

  defp check_idempotency(nil), do: :not_found

  defp check_idempotency(key) do
    query = from o in Order, where: o.idempotency_key == ^key, preload: [:event]

    case Repo.one(query) do
      nil -> :not_found
      order -> {:ok, order}
    end
  end

  defp do_purchase_tickets(event_id, attrs) do
    Repo.transaction(fn ->
      with {:ok, event} <- get_published_event(event_id),
           {:ok, _event} <- Events.decrement_tickets(event_id, attrs[:quantity] || 1),
           {:ok, charge} <- process_payment(event, attrs),
           {:ok, order} <- create_order(event, attrs, charge),
           :ok <- enqueue_confirmation_email(order) do
        Repo.preload(order, :event)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp get_published_event(event_id) do
    case Events.get_event(event_id) do
      nil ->
        {:error, :event_not_found}

      %{status: "published", date: date} = event ->
        if DateTime.compare(date, DateTime.utc_now()) == :gt do
          {:ok, event}
        else
          {:error, :event_ended}
        end

      _ ->
        {:error, :event_not_available}
    end
  end

  defp process_payment(event, attrs) do
    quantity = attrs[:quantity] || 1
    total_amount = Decimal.mult(event.ticket_price, quantity)

    payment_intent = %{
      amount: total_amount,
      currency: "usd",
      customer_email: attrs[:customer_email],
      description: "#{quantity} ticket(s) for #{event.name}",
      idempotency_key: attrs[:idempotency_key]
    }

    case Gateway.charge(payment_intent) do
      {:ok, charge} -> {:ok, charge}
      {:error, reason} -> {:error, {:payment_failed, reason}}
    end
  end

  defp create_order(event, attrs, charge) do
    quantity = attrs[:quantity] || 1
    total_amount = Decimal.mult(event.ticket_price, quantity)

    order_attrs =
      attrs
      |> Map.put(:event_id, event.id)
      |> Map.put(:unit_price, event.ticket_price)
      |> Map.put(:total_amount, total_amount)
      |> Map.put(:status, "confirmed")
      |> Map.put(:charge_id, charge.id)
      |> Map.put(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))

    %Order{}
    |> Order.changeset(order_attrs)
    |> Repo.insert()
  end

  defp enqueue_confirmation_email(order) do
    case Oban.insert(OrderConfirmationEmail.new(%{order_id: order.id})) do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, {:email_enqueue_failed, reason}}
    end
  end

  def get_order(id) do
    query = from o in Order, where: o.id == ^id, preload: [:event]
    Repo.one(query)
  end

  def get_order!(id) do
    query = from o in Order, where: o.id == ^id, preload: [:event]
    Repo.one!(query)
  end

  def list_orders(opts \\ []) do
    limit = min(opts[:limit] || @default_limit, @max_limit)
    offset = opts[:offset] || 0

    Order
    |> filter_by_customer_email(opts[:customer_email])
    |> filter_by_event(opts[:event_id])
    |> filter_by_order_status(opts[:status])
    |> order_by([o], desc: o.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:event)
    |> Repo.all()
  end

  def count_orders(opts \\ []) do
    Order
    |> filter_by_customer_email(opts[:customer_email])
    |> filter_by_event(opts[:event_id])
    |> filter_by_order_status(opts[:status])
    |> Repo.aggregate(:count)
  end

  defp filter_by_customer_email(query, nil), do: query
  defp filter_by_customer_email(query, email), do: where(query, [o], o.customer_email == ^email)

  defp filter_by_event(query, nil), do: query
  defp filter_by_event(query, event_id), do: where(query, [o], o.event_id == ^event_id)

  defp filter_by_order_status(query, nil), do: query
  defp filter_by_order_status(query, status), do: where(query, [o], o.status == ^status)

  def cancel_order(%Order{id: order_id}) do
    Repo.transaction(fn ->
      # Lock the order row and re-check status to handle concurrent cancellations
      query = from o in Order, where: o.id == ^order_id, lock: "FOR UPDATE"

      case Repo.one(query) do
        %Order{status: "confirmed"} = order ->
          with {:ok, _refund} <- refund_payment(order),
               {:ok, _event} <- Events.increment_tickets(order.event_id, order.quantity),
               {:ok, updated_order} <- do_cancel_order(order) do
            Repo.preload(updated_order, :event)
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        %Order{} ->
          Repo.rollback(:invalid_order_status)

        nil ->
          Repo.rollback(:order_not_found)
      end
    end)
  end

  defp refund_payment(%Order{charge_id: nil}), do: {:ok, nil}

  defp refund_payment(%Order{charge_id: charge_id}) do
    case Gateway.refund(charge_id) do
      {:ok, refund} -> {:ok, refund}
      {:error, reason} -> {:error, {:refund_failed, reason}}
    end
  end

  defp do_cancel_order(order) do
    order
    |> Order.cancel_changeset()
    |> Repo.update()
  end

  def get_order_stats(event_id) do
    query =
      from o in Order,
        where: o.event_id == ^event_id and o.status == "confirmed",
        select: %{
          total_orders: count(o.id),
          total_tickets: sum(o.quantity),
          total_revenue: sum(o.total_amount)
        }

    Repo.one(query)
  end
end
