defmodule EventManagment.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :venue, :string, null: false
      add :date, :utc_datetime, null: false
      add :ticket_price, :decimal, precision: 10, scale: 2, null: false
      add :total_tickets, :integer, null: false
      add :available_tickets, :integer, null: false
      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime)
    end

    create index(:events, [:status])
    create index(:events, [:date])
    create index(:events, [:status, :date])
  end
end
