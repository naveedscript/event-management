defmodule EventManagmentWeb.OrderController do
  @moduledoc """
  Handles HTTP requests for order and ticket management.

  ## Endpoints

  - `GET /api/orders` - List orders with optional filters
  - `GET /api/orders/:id` - Get order details
  - `POST /api/events/:event_id/purchase` - Purchase tickets for an event
  - `POST /api/orders/:id/cancel` - Cancel an order

  ## Purchase Endpoint

  The purchase endpoint supports idempotency via the `idempotency_key` parameter.
  If the same key is used for multiple requests, only the first will be processed.
  Subsequent requests return the existing order.

  ## Rate Limiting

  The purchase endpoint has stricter rate limits (10 requests/minute)
  compared to other endpoints (100 requests/minute).
  """
  use EventManagmentWeb, :controller

  alias EventManagment.Ticketing

  action_fallback EventManagmentWeb.FallbackController

  @doc """
  Lists orders with optional filtering and pagination.

  ## Query Parameters

  - `customer_email` - Filter by customer email
  - `event_id` - Filter by event UUID
  - `status` - Filter by status: pending, confirmed, cancelled, refunded
  - `limit` - Maximum results (default: 50, max: 100)
  - `offset` - Skip N results for pagination
  """
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

  @doc """
  Gets a single order by ID.
  """
  def show(conn, %{"id" => id}) do
    case Ticketing.get_order(id) do
      nil -> {:error, :not_found}
      order -> render(conn, :show, order: order)
    end
  end

  @doc """
  Purchases tickets for an event.

  ## Request Body

  ```json
  {
    "order": {
      "customer_email": "john@example.com",
      "customer_name": "John Doe",
      "quantity": 2,
      "idempotency_key": "optional-unique-key"
    }
  }
  ```

  ## Response Codes

  - 201 Created - Order successfully created
  - 404 Not Found - Event doesn't exist
  - 422 Unprocessable Entity - Validation error or business rule violation
  - 429 Too Many Requests - Rate limit exceeded
  """
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

      {:error, :insufficient_tickets} ->
        {:error, :unprocessable_entity, "Not enough tickets available"}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Cancels an order and returns tickets to inventory.

  Only confirmed orders can be cancelled.

  ## Response Codes

  - 200 OK - Order successfully cancelled
  - 404 Not Found - Order doesn't exist
  - 422 Unprocessable Entity - Order cannot be cancelled (wrong status)
  """
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
