defmodule EventManagment.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

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

  def update_changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:venue, min: 3, max: 255)
    |> validate_number(:ticket_price, greater_than_or_equal_to: 0)
    |> validate_number(:total_tickets, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
  end

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

  def statuses, do: @statuses
end
