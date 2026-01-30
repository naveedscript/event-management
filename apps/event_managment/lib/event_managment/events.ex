defmodule EventManagment.Events do
  @moduledoc """
  The Events context - handles all event-related business logic.

  This context is responsible for:
  - Creating and managing events
  - Querying event information
  - Marking events as completed

  It does NOT directly handle ticket purchases - that is the responsibility
  of the Ticketing context.

  ## Error Types

  This context returns standardized error tuples:
  - `{:error, :event_not_found}` - Event doesn't exist
  - `{:error, :event_not_available}` - Event is not in published state
  - `{:error, :insufficient_tickets}` - Not enough tickets available
  - `{:error, :invalid_status_transition}` - Cannot transition to requested status
  - `{:error, %Ecto.Changeset{}}` - Validation errors
  """
  import Ecto.Query, warn: false

  alias EventManagment.Repo
  alias EventManagment.Events.Event

  @type event_error ::
          :event_not_found
          | :event_not_available
          | :insufficient_tickets
          | :invalid_status_transition

  @type list_opts :: [
          status: String.t() | nil,
          upcoming: boolean() | nil,
          limit: pos_integer() | nil,
          offset: non_neg_integer() | nil
        ]

  @default_limit 50
  @max_limit 100

  @doc """
  Returns the list of events.

  ## Options
    - `:status` - Filter by status (draft, published, completed, cancelled)
    - `:upcoming` - Only return events with date > now (boolean)
    - `:limit` - Maximum number of events to return (default: #{@default_limit}, max: #{@max_limit})
    - `:offset` - Number of events to skip (for pagination)

  ## Examples

      iex> list_events()
      [%Event{}, ...]

      iex> list_events(status: "published", upcoming: true, limit: 10)
      [%Event{}, ...]

  """
  @spec list_events(list_opts()) :: [Event.t()]
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

  defp filter_by_status(query, nil), do: query

  defp filter_by_status(query, status) do
    where(query, [e], e.status == ^status)
  end

  defp filter_upcoming(query, true) do
    now = DateTime.utc_now()
    where(query, [e], e.date > ^now)
  end

  defp filter_upcoming(query, _), do: query

  @doc """
  Returns the total count of events matching the given filters.

  Useful for pagination.

  ## Options
    - `:status` - Filter by status
    - `:upcoming` - Only count events with date > now
  """
  @spec count_events(list_opts()) :: non_neg_integer()
  def count_events(opts \\ []) do
    Event
    |> filter_by_status(opts[:status])
    |> filter_upcoming(opts[:upcoming])
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a single event.

  Returns `nil` if the Event does not exist.

  ## Examples

      iex> get_event("valid-uuid")
      %Event{}

      iex> get_event("invalid-uuid")
      nil

  """
  @spec get_event(Ecto.UUID.t()) :: Event.t() | nil
  def get_event(id), do: Repo.get(Event, id)

  @doc """
  Gets a single event, raising if not found.

  ## Examples

      iex> get_event!("valid-uuid")
      %Event{}

      iex> get_event!("invalid-uuid")
      ** (Ecto.NoResultsError)

  """
  @spec get_event!(Ecto.UUID.t()) :: Event.t()
  def get_event!(id), do: Repo.get!(Event, id)

  @doc """
  Creates an event.

  Events are created in "draft" status by default and must be published
  before tickets can be purchased.

  ## Examples

      iex> create_event(%{name: "Concert", venue: "Stadium", ...})
      {:ok, %Event{}}

      iex> create_event(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_event(map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an event.

  ## Examples

      iex> update_event(event, %{name: "New Name"})
      {:ok, %Event{}}

      iex> update_event(event, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_event(Event.t(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an event.

  Note: Events with orders cannot be deleted due to foreign key constraints.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

  """
  @spec delete_event(Event.t()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.
  """
  @spec change_event(Event.t(), map()) :: Ecto.Changeset.t()
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Decrements available tickets for an event atomically.

  Uses optimistic locking to prevent race conditions (overselling).
  This is the ONLY way to modify ticket inventory - direct updates are not allowed.

  ## Error Responses
    - `{:error, :event_not_found}` - Event doesn't exist
    - `{:error, :event_not_available}` - Event is not published
    - `{:error, :insufficient_tickets}` - Not enough tickets available

  ## Examples

      iex> decrement_tickets(event_id, 2)
      {:ok, %Event{}}

      iex> decrement_tickets(event_id, 1000)
      {:error, :insufficient_tickets}

  """
  @spec decrement_tickets(Ecto.UUID.t(), pos_integer()) ::
          {:ok, Event.t()} | {:error, event_error()}
  def decrement_tickets(event_id, quantity) when is_integer(quantity) and quantity > 0 do
    query =
      from e in Event,
        where:
          e.id == ^event_id and
            e.status == "published" and
            e.available_tickets >= ^quantity,
        select: e

    case Repo.update_all(
           query,
           [inc: [available_tickets: -quantity]],
           returning: true
         ) do
      {1, [event]} ->
        {:ok, event}

      {0, _} ->
        determine_decrement_error(event_id, quantity)
    end
  end

  defp determine_decrement_error(event_id, quantity) do
    case get_event(event_id) do
      nil ->
        {:error, :event_not_found}

      %Event{status: status} when status != "published" ->
        {:error, :event_not_available}

      %Event{available_tickets: available} when available < quantity ->
        {:error, :insufficient_tickets}

      _ ->
        {:error, :insufficient_tickets}
    end
  end

  @doc """
  Increments available tickets for an event (e.g., for refunds).

  ## Error Responses
    - `{:error, :event_not_found}` - Event doesn't exist

  """
  @spec increment_tickets(Ecto.UUID.t(), pos_integer()) ::
          {:ok, Event.t()} | {:error, :event_not_found}
  def increment_tickets(event_id, quantity) when is_integer(quantity) and quantity > 0 do
    query = from e in Event, where: e.id == ^event_id, select: e

    case Repo.update_all(query, [inc: [available_tickets: quantity]]) do
      {1, [event]} -> {:ok, event}
      {0, _} -> {:error, :event_not_found}
    end
  end

  @doc """
  Marks all past events as completed.

  This is called by the scheduled EventCompletionJob daily.
  Only events with status "published" and date < now will be updated.

  Returns the number of events marked as completed.
  """
  @spec mark_past_events_completed() :: {:ok, non_neg_integer()}
  def mark_past_events_completed do
    now = DateTime.utc_now()

    query =
      from e in Event,
        where: e.date < ^now and e.status == "published"

    {count, _} = Repo.update_all(query, set: [status: "completed"])
    {:ok, count}
  end

  @doc """
  Publishes an event, making it available for ticket purchases.

  Only events in "draft" status can be published.

  ## Error Responses
    - `{:error, :invalid_status_transition}` - Event is not in draft status

  """
  @spec publish_event(Event.t()) ::
          {:ok, Event.t()} | {:error, :invalid_status_transition | Ecto.Changeset.t()}
  def publish_event(%Event{status: "draft"} = event) do
    event
    |> Event.status_changeset("published")
    |> Repo.update()
  end

  def publish_event(%Event{}) do
    {:error, :invalid_status_transition}
  end

  @doc """
  Cancels an event.

  Events can be cancelled from any status except "completed".
  """
  @spec cancel_event(Event.t()) ::
          {:ok, Event.t()} | {:error, :invalid_status_transition | Ecto.Changeset.t()}
  def cancel_event(%Event{status: "completed"}) do
    {:error, :invalid_status_transition}
  end

  def cancel_event(%Event{} = event) do
    event
    |> Event.status_changeset("cancelled")
    |> Repo.update()
  end
end
