defmodule EventManagmentWeb.EventController do
  @moduledoc """
  Handles HTTP requests for event management.

  ## Endpoints

  - `GET /api/events` - List events with optional filters
  - `GET /api/events/:id` - Get event details
  - `POST /api/events` - Create new event
  - `PUT /api/events/:id` - Update event
  - `DELETE /api/events/:id` - Delete event
  - `POST /api/events/:id/publish` - Publish a draft event

  ## Query Parameters (GET /api/events)

  - `status` - Filter by status: draft, published, completed, cancelled
  - `upcoming` - Set to "true" to only show future events
  - `limit` - Maximum results (default: 50, max: 100)
  - `offset` - Skip N results for pagination
  """
  use EventManagmentWeb, :controller

  alias EventManagment.Events
  alias EventManagment.Events.Event

  action_fallback EventManagmentWeb.FallbackController

  @doc """
  Lists events with optional filtering and pagination.
  """
  def index(conn, params) do
    opts = [
      status: params["status"],
      upcoming: params["upcoming"] == "true",
      limit: parse_int(params["limit"]),
      offset: parse_int(params["offset"])
    ]

    events = Events.list_events(opts)
    total = Events.count_events(opts)

    conn
    |> put_resp_header("x-total-count", to_string(total))
    |> render(:index, events: events)
  end

  @doc """
  Gets a single event by ID.
  """
  def show(conn, %{"id" => id}) do
    case Events.get_event(id) do
      nil -> {:error, :not_found}
      event -> render(conn, :show, event: event)
    end
  end

  @doc """
  Creates a new event.

  Events are created in "draft" status and must be published
  before tickets can be purchased.
  """
  def create(conn, %{"event" => event_params}) do
    with {:ok, %Event{} = event} <- Events.create_event(event_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/events/#{event}")
      |> render(:show, event: event)
    end
  end

  @doc """
  Updates an existing event.
  """
  def update(conn, %{"id" => id, "event" => event_params}) do
    case Events.get_event(id) do
      nil ->
        {:error, :not_found}

      event ->
        with {:ok, %Event{} = event} <- Events.update_event(event, event_params) do
          render(conn, :show, event: event)
        end
    end
  end

  @doc """
  Deletes an event.

  Note: Events with orders cannot be deleted.
  """
  def delete(conn, %{"id" => id}) do
    case Events.get_event(id) do
      nil ->
        {:error, :not_found}

      event ->
        with {:ok, %Event{}} <- Events.delete_event(event) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  @doc """
  Publishes a draft event, making it available for ticket purchases.
  """
  def publish(conn, %{"event_id" => id}) do
    case Events.get_event(id) do
      nil ->
        {:error, :not_found}

      event ->
        case Events.publish_event(event) do
          {:ok, event} ->
            render(conn, :show, event: event)

          {:error, :invalid_status_transition} ->
            {:error, :unprocessable_entity, "Only draft events can be published"}

          {:error, changeset} ->
            {:error, changeset}
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
