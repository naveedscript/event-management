defmodule EventManagment.Ticketing.Order do
  @moduledoc """
  Schema for orders in the ticketing system.

  ## Statuses

  Orders follow a lifecycle:
  - `pending` - Initial state (not used in current implementation)
  - `confirmed` - Payment successful, tickets reserved
  - `cancelled` - Order cancelled, tickets returned to inventory
  - `refunded` - Full refund processed

  ## Business Rules

  - Maximum 10 tickets per order
  - Idempotency key prevents duplicate purchases
  - Only confirmed orders can be cancelled
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type status :: String.t()
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          customer_email: String.t() | nil,
          customer_name: String.t() | nil,
          quantity: pos_integer() | nil,
          unit_price: Decimal.t() | nil,
          total_amount: Decimal.t() | nil,
          status: status(),
          idempotency_key: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          event_id: Ecto.UUID.t() | nil,
          event: EventManagment.Events.Event.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @statuses ~w(pending confirmed cancelled refunded)
  @max_quantity 10

  # More robust email validation regex
  # Allows: local@domain.tld, local+tag@domain.tld, local.name@subdomain.domain.tld
  @email_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/

  schema "orders" do
    field :customer_email, :string
    field :customer_name, :string
    field :quantity, :integer
    field :unit_price, :decimal
    field :total_amount, :decimal
    field :status, :string, default: "pending"
    field :idempotency_key, :string
    field :confirmed_at, :utc_datetime

    belongs_to :event, EventManagment.Events.Event

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(customer_email customer_name quantity event_id)a
  @optional_fields ~w(unit_price total_amount status idempotency_key confirmed_at)a

  @doc """
  Changeset for creating a new order.

  ## Validations
  - `customer_email` - Must be a valid email format
  - `customer_name` - 2-255 characters
  - `quantity` - 1-#{@max_quantity} tickets
  - `idempotency_key` - Must be unique if provided
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(order, attrs) do
    order
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_email()
    |> validate_length(:customer_name, min: 2, max: 255)
    |> validate_number(:quantity, greater_than: 0, less_than_or_equal_to: @max_quantity)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:idempotency_key)
    |> foreign_key_constraint(:event_id)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:customer_email, @email_regex, message: "must be a valid email address")
    |> update_change(:customer_email, &String.downcase/1)
  end

  @doc """
  Changeset for confirming an order.
  """
  @spec confirm_changeset(t()) :: Ecto.Changeset.t()
  def confirm_changeset(order) do
    order
    |> change(%{
      status: "confirmed",
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Changeset for cancelling an order.
  """
  @spec cancel_changeset(t()) :: Ecto.Changeset.t()
  def cancel_changeset(order) do
    order
    |> change(%{status: "cancelled"})
  end

  @doc """
  Changeset for refunding an order.
  """
  @spec refund_changeset(t()) :: Ecto.Changeset.t()
  def refund_changeset(order) do
    order
    |> change(%{status: "refunded"})
  end

  @doc """
  Returns all valid status values.
  """
  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc """
  Returns the maximum allowed quantity per order.
  """
  @spec max_quantity() :: pos_integer()
  def max_quantity, do: @max_quantity
end
