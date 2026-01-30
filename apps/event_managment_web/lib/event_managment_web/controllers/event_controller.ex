defmodule EventManagmentWeb.EventController do
  use EventManagmentWeb, :controller

  alias EventManagment.Events
  alias EventManagment.Events.Event

  action_fallback EventManagmentWeb.FallbackController

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

  def show(conn, %{"id" => id}) do
    case Events.get_event(id) do
      nil -> {:error, :not_found}
      event -> render(conn, :show, event: event)
    end
  end

  def create(conn, %{"event" => event_params}) do
    with {:ok, %Event{} = event} <- Events.create_event(event_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/events/#{event}")
      |> render(:show, event: event)
    end
  end

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
