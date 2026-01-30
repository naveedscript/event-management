defmodule EventManagment.TicketingTest do
  # Not async due to shared mock state
  use EventManagment.DataCase, async: false

  alias EventManagment.Ticketing
  alias EventManagment.Ticketing.Order
  alias EventManagment.Events
  alias EventManagment.Notifications.EmailService
  alias EventManagment.Payments.Gateway

  describe "purchase_tickets/2" do
    test "creates an order and decrements tickets" do
      event = insert(:published_event, %{available_tickets: 10})

      attrs = %{
        customer_email: "buyer@example.com",
        customer_name: "John Doe",
        quantity: 2
      }

      assert {:ok, %Order{} = order} = Ticketing.purchase_tickets(event.id, attrs)
      assert order.customer_email == "buyer@example.com"
      assert order.quantity == 2
      assert order.status == "confirmed"
      assert order.charge_id != nil
      assert Decimal.equal?(order.total_amount, Decimal.mult(event.ticket_price, 2))

      # Verify tickets were decremented
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 8

      # Verify payment was processed
      charges = Gateway.Mock.get_charges()
      assert length(charges) >= 1
    end

    test "enqueues confirmation email" do
      event = insert(:published_event)

      attrs = %{
        customer_email: "buyer@example.com",
        customer_name: "John Doe",
        quantity: 1
      }

      assert {:ok, _order} = Ticketing.purchase_tickets(event.id, attrs)

      # Check that email was sent via mock
      emails = EmailService.Mock.get_sent_emails()
      assert length(emails) == 1
      assert hd(emails).to == "buyer@example.com"
    end

    test "returns error for non-existent event" do
      attrs = %{customer_email: "buyer@example.com", customer_name: "John", quantity: 1}
      assert {:error, :event_not_found} = Ticketing.purchase_tickets(Ecto.UUID.generate(), attrs)
    end

    test "returns error for non-published event" do
      event = insert(:event, %{status: "draft"})
      attrs = %{customer_email: "buyer@example.com", customer_name: "John", quantity: 1}
      assert {:error, :event_not_available} = Ticketing.purchase_tickets(event.id, attrs)
    end

    test "returns error for past events" do
      past_date = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      event = insert(:event, %{status: "published", date: past_date})
      attrs = %{customer_email: "buyer@example.com", customer_name: "John", quantity: 1}
      assert {:error, :event_ended} = Ticketing.purchase_tickets(event.id, attrs)
    end

    test "returns error when insufficient tickets" do
      event = insert(:published_event, %{available_tickets: 1})
      attrs = %{customer_email: "buyer@example.com", customer_name: "John", quantity: 5}
      assert {:error, :insufficient_tickets} = Ticketing.purchase_tickets(event.id, attrs)
    end

    test "validates quantity is between 1 and 10" do
      event = insert(:published_event, %{available_tickets: 100})

      # Quantity too high
      attrs = %{customer_email: "buyer@example.com", customer_name: "John", quantity: 11}
      assert {:error, %Ecto.Changeset{} = changeset} = Ticketing.purchase_tickets(event.id, attrs)
      assert "must be less than or equal to 10" in errors_on(changeset).quantity
    end

    test "supports idempotency - returns existing order for same key" do
      event = insert(:published_event, %{available_tickets: 10})

      attrs = %{
        customer_email: "buyer@example.com",
        customer_name: "John",
        quantity: 2,
        idempotency_key: "unique-key-123"
      }

      assert {:ok, order1} = Ticketing.purchase_tickets(event.id, attrs)
      assert {:ok, order2} = Ticketing.purchase_tickets(event.id, attrs)

      # Same order returned
      assert order1.id == order2.id

      # Tickets only decremented once
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 8
    end

    test "rolls back when payment fails" do
      event = insert(:published_event, %{available_tickets: 10})

      Gateway.Mock.set_failure_mode(:card_declined)

      attrs = %{
        customer_email: "buyer@example.com",
        customer_name: "John Doe",
        quantity: 2
      }

      assert {:error, {:payment_failed, _reason}} = Ticketing.purchase_tickets(event.id, attrs)

      # Tickets should not have been decremented
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 10

      Gateway.Mock.set_failure_mode(nil)
    end

    test "handles concurrent purchases safely" do
      event = insert(:published_event, %{available_tickets: 5})

      # Try to buy 2 tickets each from 5 concurrent requests
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            attrs = %{
              customer_email: "buyer#{i}@example.com",
              customer_name: "Buyer #{i}",
              quantity: 2
            }

            Ticketing.purchase_tickets(event.id, attrs)
          end)
        end

      results = Task.await_many(tasks)

      # Only 2 should succeed (5 tickets / 2 per order = 2 orders)
      successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)
      failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

      assert successes == 2
      assert failures == 3

      # Verify final ticket count
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 1
    end
  end

  describe "get_order/1" do
    test "returns order with event preloaded" do
      event = insert(:published_event)
      order = insert(:order, %{event: event})

      fetched = Ticketing.get_order(order.id)
      assert fetched.id == order.id
      assert fetched.event.id == event.id
    end

    test "returns nil for non-existent order" do
      assert Ticketing.get_order(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_orders/1" do
    test "returns all orders" do
      order = insert(:order)
      orders = Ticketing.list_orders()
      assert length(orders) == 1
      assert hd(orders).id == order.id
    end

    test "filters by customer email" do
      order1 = insert(:order, %{customer_email: "alice@example.com"})
      _order2 = insert(:order, %{customer_email: "bob@example.com"})

      orders = Ticketing.list_orders(customer_email: "alice@example.com")
      assert length(orders) == 1
      assert hd(orders).id == order1.id
    end

    test "filters by event_id" do
      event1 = insert(:published_event)
      event2 = insert(:published_event)

      order1 = insert(:order, %{event: event1})
      _order2 = insert(:order, %{event: event2})

      orders = Ticketing.list_orders(event_id: event1.id)
      assert length(orders) == 1
      assert hd(orders).id == order1.id
    end
  end

  describe "cancel_order/1" do
    test "cancels a confirmed order and returns tickets" do
      event = insert(:published_event, %{available_tickets: 8})
      order = insert(:order, %{event: event, quantity: 2, status: "confirmed"})

      assert {:ok, cancelled} = Ticketing.cancel_order(order)
      assert cancelled.status == "cancelled"

      # Tickets should be returned
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 10
    end

    test "returns error for non-confirmed orders" do
      order = insert(:order, %{status: "cancelled"})
      assert {:error, :invalid_order_status} = Ticketing.cancel_order(order)
    end

    test "processes refund when order has charge_id" do
      event = insert(:published_event, %{available_tickets: 8})
      order = insert(:order, %{event: event, quantity: 2, status: "confirmed", charge_id: "ch_test_123"})

      assert {:ok, _cancelled} = Ticketing.cancel_order(order)

      refunds = Gateway.Mock.get_refunds()
      assert length(refunds) >= 1
      assert hd(refunds).charge_id == "ch_test_123"
    end

    test "rolls back when refund fails" do
      event = insert(:published_event, %{available_tickets: 8})
      order = insert(:order, %{event: event, quantity: 2, status: "confirmed", charge_id: "ch_test_456"})

      Gateway.Mock.set_failure_mode(:timeout)

      assert {:error, {:refund_failed, :timeout}} = Ticketing.cancel_order(order)

      # Tickets should NOT be returned
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 8

      # Order should still be confirmed
      assert Ticketing.get_order(order.id).status == "confirmed"

      Gateway.Mock.set_failure_mode(nil)
    end

    test "handles concurrent cancellation safely" do
      event = insert(:published_event, %{available_tickets: 8})
      order = insert(:order, %{event: event, quantity: 2, status: "confirmed"})

      tasks =
        for _ <- 1..3 do
          Task.async(fn ->
            # Re-fetch the order to get fresh data
            fresh_order = Ticketing.get_order(order.id)
            Ticketing.cancel_order(fresh_order)
          end)
        end

      results = Task.await_many(tasks)

      # Only one should succeed
      successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)
      failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

      assert successes == 1
      assert failures == 2

      # Tickets should be returned exactly once
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 10
    end
  end
end
