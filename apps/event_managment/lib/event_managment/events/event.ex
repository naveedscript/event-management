defmodule EventManagment.Events.Event do
  @moduledoc """
  Schema for events in the ticketing system.

  ## Statuses

  Events follow a lifecycle:
  - `draft` - Initial state, not visible for purchase
  - `published` - Available for ticket purchases
  - `completed` - Event date has passed (set automatically by scheduled job)
  - `cancelled` - Event was cancelled

  ## Fields

  - `name` - Event name (3-255 characters)
  - `description` - Optional event description
  - `venue` - Event location (3-255 characters)
  - `date` - Event date/time in UTC (must be in the future for new events)
  - `ticket_price` - Price per ticket (Decimal, >= 0)
  - `total_tickets` - Total capacity (positive integer)
  - `available_tickets` - Current inventory (managed by Ticketing context)
  - `status` - Current lifecycle status
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type status :: String.t()
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          venue: String.t() | nil,
          date: DateTime.t() | nil,
          ticket_price: Decimal.t() | nil,
          total_tickets: pos_integer() | nil,
          available_tickets: non_neg_integer() | nil,
          status: status(),
          orders: [EventManagment.Ticketing.Order.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @statuses ~w(draft published completed cancelled)

  schema "events" do
    field :name, :string
    field :description, :string
    field :venue, :string
    field :date, :utc_datetime
    field :ticket_price, :decimal
    field :total_tickets, :integer
    field :available_tickets, :integer
    field :status, :string, default: "draft"

    has_many :orders, EventManagment.Ticketing.Order

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name venue date ticket_price total_tickets)a
  @optional_fields ~w(description status available_tickets)a

  @doc """
  Changeset for creating a new event.

  Validates all required fields and sets `available_tickets` from `total_tickets`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:venue, min: 3, max: 255)
    |> validate_number(:ticket_price, greater_than_or_equal_to: 0)
    |> validate_number(:total_tickets, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_future_date()
    |> set_available_tickets()
  end

  @doc """
  Changeset for updating an existing event.

  Does not revalidate the date (allows updating past events' details).
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:venue, min: 3, max: 255)
    |> validate_number(:ticket_price, greater_than_or_equal_to: 0)
    |> validate_number(:total_tickets, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for status transitions only.
  """
  @spec status_changeset(t(), status()) :: Ecto.Changeset.t()
  def status_changeset(event, status) do
    event
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end

  defp validate_future_date(changeset) do
    validate_change(changeset, :date, fn :date, date ->
      if DateTime.compare(date, DateTime.utc_now()) == :gt do
        []
      else
        [date: "must be in the future"]
      end
    end)
  end

  defp set_available_tickets(changeset) do
    case get_change(changeset, :total_tickets) do
      nil -> changeset
      total -> put_change(changeset, :available_tickets, total)
    end
  end

  @doc """
  Returns all valid status values.
  """
  @spec statuses() :: [status()]
  def statuses, do: @statuses
end
