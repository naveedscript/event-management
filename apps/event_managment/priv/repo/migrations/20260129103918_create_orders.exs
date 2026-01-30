defmodule EventManagment.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :customer_email, :string, null: false
      add :customer_name, :string, null: false
      add :quantity, :integer, null: false
      add :unit_price, :decimal, precision: 10, scale: 2, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :idempotency_key, :string
      add :confirmed_at, :utc_datetime

      add :event_id, references(:events, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:event_id])
    create index(:orders, [:customer_email])
    create index(:orders, [:status])
    create unique_index(:orders, [:idempotency_key], where: "idempotency_key IS NOT NULL")
  end
end
