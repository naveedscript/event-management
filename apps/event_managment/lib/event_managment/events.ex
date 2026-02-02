defmodule EventManagment.Events do
  @moduledoc """
  Context for managing events and ticket inventory.
  """
  import Ecto.Query, warn: false

  alias EventManagment.Repo
  alias EventManagment.Events.Event

  @default_limit 50
  @max_limit 100

  @doc "Lists events with optional filtering by status, upcoming, limit, offset."
  @spec list_events(keyword()) :: [Event.t()]
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

  @doc "Counts events matching the given filters."
  @spec count_events(keyword()) :: non_neg_integer()
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

  @doc "Gets a single event by ID. Returns nil if not found."
  @spec get_event(Ecto.UUID.t()) :: Event.t() | nil
  def get_event(id), do: Repo.get(Event, id)

  @doc "Gets a single event by ID. Raises if not found."
  @spec get_event!(Ecto.UUID.t()) :: Event.t()
  def get_event!(id), do: Repo.get!(Event, id)

  @doc "Creates a new event in draft status."
  @spec create_event(map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing event."
  @spec update_event(Event.t(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes an event."
  @spec delete_event(Event.t()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def delete_event(%Event{} = event), do: Repo.delete(event)

  @doc "Returns a changeset for tracking event changes."
  @spec change_event(Event.t(), map()) :: Ecto.Changeset.t()
  def change_event(%Event{} = event, attrs \\ %{}), do: Event.changeset(event, attrs)

  @doc "Atomically decrements available tickets. Uses optimistic locking to prevent overselling."
  @spec decrement_tickets(Ecto.UUID.t(), pos_integer()) ::
          {:ok, Event.t()} | {:error, :event_not_found | :event_not_available | :insufficient_tickets}
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

  @doc "Atomically increments available tickets. Used for refunds/cancellations."
  @spec increment_tickets(Ecto.UUID.t(), pos_integer()) ::
          {:ok, Event.t()} | {:error, :event_not_found}
  def increment_tickets(event_id, quantity) when is_integer(quantity) and quantity > 0 do
    query = from e in Event, where: e.id == ^event_id, select: e

    case Repo.update_all(query, [inc: [available_tickets: quantity]]) do
      {1, [event]} -> {:ok, event}
      {0, _} -> {:error, :event_not_found}
    end
  end

  @doc "Marks all past published events as completed. Called by daily cron job."
  @spec mark_past_events_completed() :: {:ok, non_neg_integer()}
  def mark_past_events_completed do
    now = DateTime.utc_now()
    query = from e in Event, where: e.date < ^now and e.status == "published"
    {count, _} = Repo.update_all(query, set: [status: "completed"])
    {:ok, count}
  end

  @doc "Publishes a draft event, making it available for purchases."
  @spec publish_event(Event.t()) :: {:ok, Event.t()} | {:error, :invalid_status_transition | Ecto.Changeset.t()}
  def publish_event(%Event{status: "draft"} = event) do
    event
    |> Event.status_changeset("published")
    |> Repo.update()
  end

  def publish_event(%Event{}), do: {:error, :invalid_status_transition}

  @doc "Cancels an event. Cannot cancel completed events."
  @spec cancel_event(Event.t()) :: {:ok, Event.t()} | {:error, :invalid_status_transition | Ecto.Changeset.t()}
  def cancel_event(%Event{status: "completed"}), do: {:error, :invalid_status_transition}

  def cancel_event(%Event{} = event) do
    event
    |> Event.status_changeset("cancelled")
    |> Repo.update()
  end
end
