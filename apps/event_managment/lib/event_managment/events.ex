defmodule EventManagment.Events do
  import Ecto.Query, warn: false

  alias EventManagment.Repo
  alias EventManagment.Events.Event

  @default_limit 50
  @max_limit 100

  def list_events(opts \\ []) do
    limit = min(opts[:limit] || @default_limit, @max_limit)
    offset = opts[:offset] || 0

    Event
    |> filter_by_status(opts[:status])
    |> filter_upcoming(opts[:upcoming])
    |> order_by([e], asc: e.date)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def count_events(opts \\ []) do
    Event
    |> filter_by_status(opts[:status])
    |> filter_upcoming(opts[:upcoming])
    |> Repo.aggregate(:count)
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [e], e.status == ^status)

  defp filter_upcoming(query, true), do: where(query, [e], e.date > ^DateTime.utc_now())
  defp filter_upcoming(query, _), do: query

  def get_event(id), do: Repo.get(Event, id)
  def get_event!(id), do: Repo.get!(Event, id)

  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_event(%Event{} = event), do: Repo.delete(event)

  def change_event(%Event{} = event, attrs \\ %{}), do: Event.changeset(event, attrs)

  def decrement_tickets(event_id, quantity) when is_integer(quantity) and quantity > 0 do
    query =
      from e in Event,
        where: e.id == ^event_id and e.status == "published" and e.available_tickets >= ^quantity,
        select: e

    case Repo.update_all(query, [inc: [available_tickets: -quantity]], returning: true) do
      {1, [event]} -> {:ok, event}
      {0, _} -> determine_decrement_error(event_id, quantity)
    end
  end

  defp determine_decrement_error(event_id, quantity) do
    case get_event(event_id) do
      nil -> {:error, :event_not_found}
      %Event{status: status} when status != "published" -> {:error, :event_not_available}
      %Event{available_tickets: available} when available < quantity -> {:error, :insufficient_tickets}
      _ -> {:error, :insufficient_tickets}
    end
  end

  def increment_tickets(event_id, quantity) when is_integer(quantity) and quantity > 0 do
    query = from e in Event, where: e.id == ^event_id, select: e

    case Repo.update_all(query, [inc: [available_tickets: quantity]]) do
      {1, [event]} -> {:ok, event}
      {0, _} -> {:error, :event_not_found}
    end
  end

  def mark_past_events_completed do
    now = DateTime.utc_now()

    query = from e in Event, where: e.date < ^now and e.status == "published"

    {count, _} = Repo.update_all(query, set: [status: "completed"])
    {:ok, count}
  end

  def publish_event(%Event{status: "draft"} = event) do
    event
    |> Event.status_changeset("published")
    |> Repo.update()
  end

  def publish_event(%Event{}), do: {:error, :invalid_status_transition}

  def cancel_event(%Event{status: "completed"}), do: {:error, :invalid_status_transition}

  def cancel_event(%Event{} = event) do
    event
    |> Event.status_changeset("cancelled")
    |> Repo.update()
  end
end
