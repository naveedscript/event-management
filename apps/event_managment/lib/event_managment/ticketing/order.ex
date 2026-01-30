defmodule EventManagment.Ticketing.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending confirmed cancelled refunded)
  @max_quantity 10
  @email_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/

  schema "orders" do
    field :customer_email, :string
    field :customer_name, :string
    field :quantity, :integer
    field :unit_price, :decimal
    field :total_amount, :decimal
    field :status, :string, default: "pending"
    field :idempotency_key, :string
    field :charge_id, :string
    field :confirmed_at, :utc_datetime

    belongs_to :event, EventManagment.Events.Event

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(customer_email customer_name quantity event_id)a
  @optional_fields ~w(unit_price total_amount status idempotency_key charge_id confirmed_at)a

  def changeset(order, attrs) do
    order
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:customer_email, @email_regex, message: "must be a valid email address")
    |> update_change(:customer_email, &String.downcase/1)
    |> validate_length(:customer_name, min: 2, max: 255)
    |> validate_number(:quantity, greater_than: 0, less_than_or_equal_to: @max_quantity)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:idempotency_key)
    |> foreign_key_constraint(:event_id)
  end

  def confirm_changeset(order) do
    change(order, %{
      status: "confirmed",
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def cancel_changeset(order), do: change(order, %{status: "cancelled"})

  def refund_changeset(order), do: change(order, %{status: "refunded"})

  def statuses, do: @statuses
  def max_quantity, do: @max_quantity
end
