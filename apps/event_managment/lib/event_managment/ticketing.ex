defmodule EventManagment.Ticketing do
  @moduledoc """
  The Ticketing context - handles ticket purchases and order management.

  This context is responsible for:
  - Processing ticket purchases
  - Managing orders
  - Coordinating with Events context for inventory
  - Triggering notifications via the Notifications context

  ## Business Rules

  - Maximum 10 tickets per order
  - Idempotency support to prevent duplicate purchases
  - Atomic inventory updates to prevent overselling
  - Only confirmed orders can be cancelled

  ## Error Types

  - `{:error, :event_not_found}` - Event doesn't exist
  - `{:error, :event_not_available}` - Event is not published
  - `{:error, :insufficient_tickets}` - Not enough tickets available
  - `{:error, :order_not_found}` - Order doesn't exist
  - `{:error, :invalid_order_status}` - Cannot perform operation on order in this status
  - `{:error, %Ecto.Changeset{}}` - Validation errors
  """
  import Ecto.Query, warn: false

  alias EventManagment.Repo
  alias EventManagment.Events
  alias EventManagment.Ticketing.Order
  alias EventManagment.Workers.OrderConfirmationEmail

  @type order_error ::
          :event_not_found
          | :event_not_available
          | :insufficient_tickets
          | :order_not_found
          | :invalid_order_status

  @type list_opts :: [
          customer_email: String.t() | nil,
          event_id: Ecto.UUID.t() | nil,
          status: String.t() | nil,
          limit: pos_integer() | nil,
          offset: non_neg_integer() | nil
        ]

  @type purchase_attrs :: %{
          required(:customer_email) => String.t(),
          required(:customer_name) => String.t(),
          optional(:quantity) => pos_integer(),
          optional(:idempotency_key) => String.t()
        }

  @default_limit 50
  @max_limit 100

  @doc """
  Purchases tickets for an event.

  This operation is atomic and handles race conditions:
  1. Validates the purchase request
  2. Decrements available tickets (with optimistic locking)
  3. Creates the order
  4. Enqueues confirmation email

  Supports idempotency via `idempotency_key` - if provided, duplicate
  requests with the same key will return the existing order.

  ## Parameters
    - `event_id` - The event UUID
    - `attrs` - Order attributes:
      - `customer_email` (required) - Customer's email address
      - `customer_name` (required) - Customer's full name
      - `quantity` (optional, default: 1) - Number of tickets (1-10)
      - `idempotency_key` (optional) - Unique key to prevent duplicate purchases

  ## Returns
    - `{:ok, %Order{}}` - Successfully created order with event preloaded
    - `{:error, :event_not_found}` - Event doesn't exist
    - `{:error, :event_not_available}` - Event is not published
    - `{:error, :insufficient_tickets}` - Not enough tickets available
    - `{:error, %Ecto.Changeset{}}` - Validation errors

  ## Examples

      iex> purchase_tickets(event_id, %{
      ...>   customer_email: "john@example.com",
      ...>   customer_name: "John Doe",
      ...>   quantity: 2
      ...> })
      {:ok, %Order{}}

  """
  @spec purchase_tickets(Ecto.UUID.t(), purchase_attrs()) ::
          {:ok, Order.t()} | {:error, order_error() | Ecto.Changeset.t()}
  def purchase_tickets(event_id, attrs) do
    case check_idempotency(attrs[:idempotency_key]) do
      {:ok, existing_order} -> {:ok, existing_order}
      :not_found -> do_purchase_tickets(event_id, attrs)
    end
  end

  defp check_idempotency(nil), do: :not_found

  defp check_idempotency(key) do
    query =
      from o in Order,
        where: o.idempotency_key == ^key,
        preload: [:event]

    case Repo.one(query) do
      nil -> :not_found
      order -> {:ok, order}
    end
  end

  defp do_purchase_tickets(event_id, attrs) do
    Repo.transaction(fn ->
      with {:ok, event} <- get_published_event(event_id),
           {:ok, _event} <- Events.decrement_tickets(event_id, attrs[:quantity] || 1),
           {:ok, order} <- create_order(event, attrs),
           :ok <- enqueue_confirmation_email(order) do
        Repo.preload(order, :event)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp get_published_event(event_id) do
    case Events.get_event(event_id) do
      nil -> {:error, :event_not_found}
      %{status: "published"} = event -> {:ok, event}
      _ -> {:error, :event_not_available}
    end
  end

  defp create_order(event, attrs) do
    quantity = attrs[:quantity] || 1
    unit_price = event.ticket_price
    total_amount = Decimal.mult(unit_price, quantity)

    order_attrs =
      attrs
      |> Map.put(:event_id, event.id)
      |> Map.put(:unit_price, unit_price)
      |> Map.put(:total_amount, total_amount)
      |> Map.put(:status, "confirmed")
      |> Map.put(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))

    %Order{}
    |> Order.changeset(order_attrs)
    |> Repo.insert()
  end

  defp enqueue_confirmation_email(order) do
    %{order_id: order.id}
    |> OrderConfirmationEmail.new()
    |> Oban.insert()

    :ok
  end

  @doc """
  Gets a single order by ID with event preloaded.

  ## Examples

      iex> get_order("valid-uuid")
      %Order{event: %Event{}}

      iex> get_order("invalid-uuid")
      nil

  """
  @spec get_order(Ecto.UUID.t()) :: Order.t() | nil
  def get_order(id) do
    query =
      from o in Order,
        where: o.id == ^id,
        preload: [:event]

    Repo.one(query)
  end

  @doc """
  Gets a single order, raising if not found.
  """
  @spec get_order!(Ecto.UUID.t()) :: Order.t()
  def get_order!(id) do
    query =
      from o in Order,
        where: o.id == ^id,
        preload: [:event]

    Repo.one!(query)
  end

  @doc """
  Lists orders with optional filters and pagination.

  ## Options
    - `:customer_email` - Filter by customer email (exact match)
    - `:event_id` - Filter by event UUID
    - `:status` - Filter by order status
    - `:limit` - Maximum results (default: #{@default_limit}, max: #{@max_limit})
    - `:offset` - Number to skip (for pagination)

  ## Examples

      iex> list_orders(customer_email: "john@example.com")
      [%Order{}, ...]

      iex> list_orders(event_id: event_id, limit: 10, offset: 20)
      [%Order{}, ...]

  """
  @spec list_orders(list_opts()) :: [Order.t()]
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

  @doc """
  Returns the total count of orders matching the given filters.

  Useful for pagination.
  """
  @spec count_orders(list_opts()) :: non_neg_integer()
  def count_orders(opts \\ []) do
    Order
    |> filter_by_customer_email(opts[:customer_email])
    |> filter_by_event(opts[:event_id])
    |> filter_by_order_status(opts[:status])
    |> Repo.aggregate(:count)
  end

  defp filter_by_customer_email(query, nil), do: query

  defp filter_by_customer_email(query, email) do
    where(query, [o], o.customer_email == ^email)
  end

  defp filter_by_event(query, nil), do: query

  defp filter_by_event(query, event_id) do
    where(query, [o], o.event_id == ^event_id)
  end

  defp filter_by_order_status(query, nil), do: query

  defp filter_by_order_status(query, status) do
    where(query, [o], o.status == ^status)
  end

  @doc """
  Cancels an order and refunds the tickets back to inventory.

  Only confirmed orders can be cancelled. Cancelled orders cannot be uncancelled.

  ## Error Responses
    - `{:error, :invalid_order_status}` - Order is not in confirmed status

  ## Examples

      iex> cancel_order(confirmed_order)
      {:ok, %Order{status: "cancelled"}}

      iex> cancel_order(cancelled_order)
      {:error, :invalid_order_status}

  """
  @spec cancel_order(Order.t()) :: {:ok, Order.t()} | {:error, order_error()}
  def cancel_order(%Order{status: "confirmed"} = order) do
    Repo.transaction(fn ->
      with {:ok, _event} <- Events.increment_tickets(order.event_id, order.quantity),
           {:ok, updated_order} <- do_cancel_order(order) do
        Repo.preload(updated_order, :event)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def cancel_order(%Order{}) do
    {:error, :invalid_order_status}
  end

  defp do_cancel_order(order) do
    order
    |> Order.cancel_changeset()
    |> Repo.update()
  end

  @doc """
  Returns order statistics for an event.

  ## Returns
    A map with:
    - `:total_orders` - Number of confirmed orders
    - `:total_tickets` - Total tickets sold
    - `:total_revenue` - Total revenue (Decimal)

  """
  @spec get_order_stats(Ecto.UUID.t()) :: %{
          total_orders: non_neg_integer(),
          total_tickets: non_neg_integer() | nil,
          total_revenue: Decimal.t() | nil
        }
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
