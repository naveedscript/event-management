defmodule EventManagment.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:events, [:status, :date, :id], name: :events_status_date_id_index)
    create_if_not_exists index(:orders, [:confirmed_at], where: "confirmed_at IS NOT NULL", name: :orders_confirmed_at_partial_index)
    create_if_not_exists index(:orders, [:event_id, :status], name: :orders_event_id_status_index)
  end
end
