defmodule EventManagment.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Adds indexes for improved query performance.

  These indexes support:
  - Filtering orders by customer email (order history lookups)
  - Composite index for common event queries (status + date)
  - Partial index for active (non-cancelled) orders
  """
  use Ecto.Migration

  def change do
    # Composite index for event listing queries that filter by status and order by date
    # Replaces individual status and date indexes for better performance
    create_if_not_exists index(:events, [:status, :date, :id],
      name: :events_status_date_id_index
    )

    # Index for order lookups by confirmation time (useful for reports)
    create_if_not_exists index(:orders, [:confirmed_at],
      where: "confirmed_at IS NOT NULL",
      name: :orders_confirmed_at_partial_index
    )

    # Composite index for order statistics queries
    create_if_not_exists index(:orders, [:event_id, :status],
      name: :orders_event_id_status_index
    )
  end
end
