defmodule EventManagment.EventsTest do
  use EventManagment.DataCase, async: true

  alias EventManagment.Events
  alias EventManagment.Events.Event

  describe "list_events/1" do
    test "returns all events" do
      event = insert(:event)
      assert Events.list_events() == [event]
    end

    test "filters by status" do
      draft = insert(:event, %{status: "draft"})
      _published = insert(:published_event)

      assert Events.list_events(status: "draft") == [draft]
    end

    test "filters upcoming events" do
      future = insert(:event, %{date: DateTime.add(DateTime.utc_now(), 7, :day)})

      past =
        insert(:event, %{
          date: DateTime.add(DateTime.utc_now(), -1, :day),
          status: "completed"
        })

      upcoming = Events.list_events(upcoming: true)
      assert future in upcoming
      refute past in upcoming
    end
  end

  describe "get_event/1" do
    test "returns the event with given id" do
      event = insert(:event)
      assert Events.get_event(event.id) == event
    end

    test "returns nil if event doesn't exist" do
      assert Events.get_event(Ecto.UUID.generate()) == nil
    end
  end

  describe "create_event/1" do
    test "creates an event with valid data" do
      attrs = event_attrs()
      assert {:ok, %Event{} = event} = Events.create_event(attrs)
      assert event.name == "New Event"
      assert event.venue == "Event Venue"
      assert event.total_tickets == 200
      assert event.available_tickets == 200
      assert event.status == "draft"
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(%{})
    end

    test "validates ticket_price is non-negative" do
      attrs = event_attrs(%{"ticket_price" => "-10.00"})
      assert {:error, changeset} = Events.create_event(attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).ticket_price
    end

    test "validates total_tickets is positive" do
      attrs = event_attrs(%{"total_tickets" => 0})
      assert {:error, changeset} = Events.create_event(attrs)
      assert "must be greater than 0" in errors_on(changeset).total_tickets
    end

    test "validates date is in the future" do
      past_date = DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.to_iso8601()
      attrs = event_attrs(%{"date" => past_date})
      assert {:error, changeset} = Events.create_event(attrs)
      assert "must be in the future" in errors_on(changeset).date
    end
  end

  describe "update_event/2" do
    test "updates event with valid data" do
      event = insert(:event)
      assert {:ok, %Event{} = updated} = Events.update_event(event, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "returns error changeset with invalid data" do
      event = insert(:event)
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{total_tickets: -1})
    end
  end

  describe "delete_event/1" do
    test "deletes the event" do
      event = insert(:event)
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert Events.get_event(event.id) == nil
    end
  end

  describe "publish_event/1" do
    test "publishes a draft event" do
      event = insert(:event, %{status: "draft"})
      assert {:ok, %Event{status: "published"}} = Events.publish_event(event)
    end

    test "returns error for non-draft event" do
      event = insert(:published_event)
      assert {:error, _message} = Events.publish_event(event)
    end
  end

  describe "decrement_tickets/2" do
    test "decrements available tickets" do
      event = insert(:published_event, %{available_tickets: 10})
      assert {:ok, updated} = Events.decrement_tickets(event.id, 3)
      assert updated.available_tickets == 7
    end

    test "returns error when insufficient tickets" do
      event = insert(:published_event, %{available_tickets: 2})
      assert {:error, :insufficient_tickets} = Events.decrement_tickets(event.id, 5)
    end

    test "returns error for non-published events" do
      event = insert(:event, %{status: "draft", available_tickets: 10})
      assert {:error, :event_not_available} = Events.decrement_tickets(event.id, 1)
    end

    test "handles concurrent requests safely" do
      event = insert(:published_event, %{available_tickets: 1})

      # Simulate concurrent requests trying to buy the last ticket
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Events.decrement_tickets(event.id, 1)
          end)
        end

      results = Task.await_many(tasks)

      # Only one should succeed
      successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)
      failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

      assert successes == 1
      assert failures == 4
    end
  end

  describe "mark_past_events_completed/0" do
    test "marks past published events as completed" do
      past_event =
        insert(:event, %{
          status: "published",
          date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      future_event = insert(:published_event)

      assert {:ok, 1} = Events.mark_past_events_completed()

      assert Events.get_event(past_event.id).status == "completed"
      assert Events.get_event(future_event.id).status == "published"
    end

    test "does not affect draft or cancelled events" do
      _draft =
        insert(:event, %{
          status: "draft",
          date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      assert {:ok, 0} = Events.mark_past_events_completed()
    end
  end
end
