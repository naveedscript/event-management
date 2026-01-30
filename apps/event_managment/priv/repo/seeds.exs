# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Or via the alias:
#
#     mix ecto.setup

import Ecto.Query

alias EventManagment.Repo
alias EventManagment.Events.Event
alias EventManagment.Ticketing.Order

# Clear existing data (useful for re-seeding)
Repo.delete_all(Order)
Repo.delete_all(Event)

IO.puts("Seeding events...")

# Create sample events
events = [
  %{
    name: "Summer Music Festival 2026",
    description: "A three-day outdoor music festival featuring top artists from around the world.",
    venue: "Central Park, New York",
    date: ~U[2026-07-15 18:00:00Z],
    ticket_price: Decimal.new("150.00"),
    total_tickets: 5000,
    available_tickets: 5000,
    status: "published"
  },
  %{
    name: "Tech Conference 2026",
    description: "Annual technology conference featuring keynotes, workshops, and networking.",
    venue: "Convention Center, San Francisco",
    date: ~U[2026-09-20 09:00:00Z],
    ticket_price: Decimal.new("299.99"),
    total_tickets: 1000,
    available_tickets: 1000,
    status: "published"
  },
  %{
    name: "Comedy Night",
    description: "Stand-up comedy show featuring local and international comedians.",
    venue: "Laugh Factory, Los Angeles",
    date: ~U[2026-03-15 20:00:00Z],
    ticket_price: Decimal.new("45.00"),
    total_tickets: 200,
    available_tickets: 200,
    status: "published"
  },
  %{
    name: "Art Exhibition Opening",
    description: "Opening night of contemporary art exhibition.",
    venue: "Modern Art Museum, Chicago",
    date: ~U[2026-04-10 19:00:00Z],
    ticket_price: Decimal.new("25.00"),
    total_tickets: 300,
    available_tickets: 300,
    status: "draft"
  },
  %{
    name: "Past Event (Completed)",
    description: "This event has already happened.",
    venue: "Some Venue",
    date: ~U[2025-12-01 18:00:00Z],
    ticket_price: Decimal.new("50.00"),
    total_tickets: 100,
    available_tickets: 0,
    status: "completed"
  }
]

created_events =
  Enum.map(events, fn attrs ->
    %Event{}
    |> Ecto.Changeset.cast(attrs, [
      :name,
      :description,
      :venue,
      :date,
      :ticket_price,
      :total_tickets,
      :available_tickets,
      :status
    ])
    |> Repo.insert!()
  end)

IO.puts("Created #{length(created_events)} events")

# Create some sample orders for the published events
IO.puts("Seeding orders...")

[concert, conference, comedy | _] = created_events

orders = [
  %{
    customer_email: "john.doe@example.com",
    customer_name: "John Doe",
    quantity: 2,
    unit_price: concert.ticket_price,
    total_amount: Decimal.mult(concert.ticket_price, 2),
    status: "confirmed",
    event_id: concert.id,
    confirmed_at: DateTime.utc_now()
  },
  %{
    customer_email: "jane.smith@example.com",
    customer_name: "Jane Smith",
    quantity: 4,
    unit_price: concert.ticket_price,
    total_amount: Decimal.mult(concert.ticket_price, 4),
    status: "confirmed",
    event_id: concert.id,
    confirmed_at: DateTime.utc_now()
  },
  %{
    customer_email: "bob@techcorp.com",
    customer_name: "Bob Wilson",
    quantity: 1,
    unit_price: conference.ticket_price,
    total_amount: conference.ticket_price,
    status: "confirmed",
    event_id: conference.id,
    confirmed_at: DateTime.utc_now()
  },
  %{
    customer_email: "alice@startup.io",
    customer_name: "Alice Johnson",
    quantity: 3,
    unit_price: comedy.ticket_price,
    total_amount: Decimal.mult(comedy.ticket_price, 3),
    status: "confirmed",
    event_id: comedy.id,
    confirmed_at: DateTime.utc_now()
  }
]

created_orders =
  Enum.map(orders, fn attrs ->
    %Order{}
    |> Ecto.Changeset.cast(attrs, [
      :customer_email,
      :customer_name,
      :quantity,
      :unit_price,
      :total_amount,
      :status,
      :event_id,
      :confirmed_at
    ])
    |> Repo.insert!()
  end)

IO.puts("Created #{length(created_orders)} orders")

# Update available tickets for events with orders
Repo.update_all(
  from(e in Event, where: e.id == ^concert.id),
  set: [available_tickets: 5000 - 6]
)

Repo.update_all(
  from(e in Event, where: e.id == ^conference.id),
  set: [available_tickets: 1000 - 1]
)

Repo.update_all(
  from(e in Event, where: e.id == ^comedy.id),
  set: [available_tickets: 200 - 3]
)

IO.puts("Seeding complete!")
