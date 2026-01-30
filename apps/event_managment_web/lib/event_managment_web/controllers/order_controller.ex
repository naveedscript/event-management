defmodule EventManagmentWeb.OrderController do
  use EventManagmentWeb, :controller

  alias EventManagment.Ticketing

  action_fallback EventManagmentWeb.FallbackController

  def index(conn, params) do
    opts = [
      customer_email: params["customer_email"],
      event_id: params["event_id"],
      status: params["status"],
      limit: parse_int(params["limit"]),
      offset: parse_int(params["offset"])
    ]

    orders = Ticketing.list_orders(opts)
    total = Ticketing.count_orders(opts)

    conn
    |> put_resp_header("x-total-count", to_string(total))
    |> render(:index, orders: orders)
  end

  def show(conn, %{"id" => id}) do
    case Ticketing.get_order(id) do
      nil -> {:error, :not_found}
      order -> render(conn, :show, order: order)
    end
  end

  def purchase(conn, %{"event_id" => event_id, "order" => order_params}) do
    attrs = %{
      customer_email: order_params["customer_email"],
      customer_name: order_params["customer_name"],
      quantity: order_params["quantity"] || 1,
      idempotency_key: order_params["idempotency_key"]
    }

    case Ticketing.purchase_tickets(event_id, attrs) do
      {:ok, order} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/orders/#{order}")
        |> render(:show, order: order)

      {:error, :event_not_found} ->
        {:error, :not_found, "Event not found"}

      {:error, :event_not_available} ->
        {:error, :unprocessable_entity, "Event is not available for purchase"}

      {:error, :event_ended} ->
        {:error, :unprocessable_entity, "Event has already ended"}

      {:error, :insufficient_tickets} ->
        {:error, :unprocessable_entity, "Not enough tickets available"}

      {:error, {:payment_failed, _reason}} ->
        {:error, :unprocessable_entity, "Payment failed"}

      {:error, {:email_enqueue_failed, _reason}} ->
        {:error, :unprocessable_entity, "Failed to process order"}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def cancel(conn, %{"id" => id}) do
    case Ticketing.get_order(id) do
      nil ->
        {:error, :not_found}

      order ->
        case Ticketing.cancel_order(order) do
          {:ok, order} ->
            render(conn, :show, order: order)

          {:error, :invalid_order_status} ->
            {:error, :unprocessable_entity, "Only confirmed orders can be cancelled"}

          {:error, reason} ->
            {:error, :unprocessable_entity, "Failed to cancel order: #{inspect(reason)}"}
        end
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
end
