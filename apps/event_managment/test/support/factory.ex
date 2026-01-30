defmodule EventManagment.Factory do
  @moduledoc """
  Test factories for creating test data.
  """
  alias EventManagment.Repo
  alias EventManagment.Events.Event
  alias EventManagment.Ticketing.Order

  # Header for default argument
  def build(factory, attrs \\ %{})

  def build(:event, attrs) do
    base = %Event{
      name: "Test Event #{System.unique_integer([:positive])}",
      description: "A test event description",
      venue: "Test Venue",
      date: DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.truncate(:second),
      ticket_price: Decimal.new("50.00"),
      total_tickets: 100,
      available_tickets: 100,
      status: "draft"
    }

    # Handle date attribute specially to ensure truncation
    attrs = truncate_dates(attrs)
    struct!(base, attrs)
  end

  def build(:published_event, attrs) do
    build(:event, Map.put(attrs, :status, "published"))
  end

  def build(:order, attrs) do
    event = attrs[:event] || insert(:published_event)

    base = %Order{
      customer_email: "customer#{System.unique_integer([:positive])}@example.com",
      customer_name: "Test Customer",
      quantity: 2,
      unit_price: event.ticket_price,
      total_amount: Decimal.mult(event.ticket_price, 2),
      status: "confirmed",
      event_id: event.id,
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    attrs = attrs |> Map.delete(:event) |> truncate_dates()
    struct!(base, attrs)
  end

  def insert(factory, attrs \\ %{}) do
    factory
    |> build(attrs)
    |> Repo.insert!()
  end

  def event_attrs(attrs \\ %{}) do
    %{
      "name" => "New Event",
      "description" => "Event description",
      "venue" => "Event Venue",
      "date" => DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.to_iso8601(),
      "ticket_price" => "75.00",
      "total_tickets" => 200
    }
    |> Map.merge(attrs)
  end

  def order_attrs(attrs \\ %{}) do
    %{
      "customer_email" => "buyer@example.com",
      "customer_name" => "John Doe",
      "quantity" => 2
    }
    |> Map.merge(attrs)
  end

  # Helper to truncate DateTime values in attrs
  defp truncate_dates(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, %DateTime{} = dt}, acc -> Map.put(acc, key, DateTime.truncate(dt, :second))
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
