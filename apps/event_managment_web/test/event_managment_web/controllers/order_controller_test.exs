defmodule EventManagmentWeb.OrderControllerTest do
  use EventManagmentWeb.ConnCase, async: true

  alias EventManagment.Events

  describe "GET /api/orders" do
    test "lists all orders", %{conn: conn} do
      order = insert(:order)

      conn = get(conn, ~p"/api/orders")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == order.id
    end

    test "filters by customer email", %{conn: conn} do
      order = insert(:order, %{customer_email: "alice@example.com"})
      _other = insert(:order, %{customer_email: "bob@example.com"})

      conn = get(conn, ~p"/api/orders?customer_email=alice@example.com")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == order.id
    end
  end

  describe "GET /api/orders/:id" do
    test "returns order when found", %{conn: conn} do
      order = insert(:order)

      conn = get(conn, ~p"/api/orders/#{order.id}")
      response = json_response(conn, 200)

      assert response["data"]["id"] == order.id
      assert response["data"]["customer_email"] == order.customer_email
      assert response["data"]["event"]["id"] == order.event_id
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = get(conn, ~p"/api/orders/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/events/:event_id/purchase" do
    test "creates order with valid data", %{conn: conn} do
      event = insert(:published_event, %{available_tickets: 10})

      attrs = order_attrs()
      conn = post(conn, ~p"/api/events/#{event.id}/purchase", order: attrs)
      response = json_response(conn, 201)

      assert response["data"]["customer_email"] == "buyer@example.com"
      assert response["data"]["quantity"] == 2
      assert response["data"]["status"] == "confirmed"

      # Verify tickets were decremented
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 8
    end

    test "returns 404 for non-existent event", %{conn: conn} do
      attrs = order_attrs()
      conn = post(conn, ~p"/api/events/#{Ecto.UUID.generate()}/purchase", order: attrs)
      response = json_response(conn, 404)

      assert response["errors"]["detail"] == "Event not found"
    end

    test "returns 422 for non-published event", %{conn: conn} do
      event = insert(:event, %{status: "draft"})

      attrs = order_attrs()
      conn = post(conn, ~p"/api/events/#{event.id}/purchase", order: attrs)
      response = json_response(conn, 422)

      assert response["errors"]["detail"] == "Event is not available for purchase"
    end

    test "returns 422 when insufficient tickets", %{conn: conn} do
      event = insert(:published_event, %{available_tickets: 1})

      attrs = order_attrs(%{"quantity" => 5})
      conn = post(conn, ~p"/api/events/#{event.id}/purchase", order: attrs)
      response = json_response(conn, 422)

      assert response["errors"]["detail"] == "Not enough tickets available"
    end

    test "returns validation errors for invalid data", %{conn: conn} do
      event = insert(:published_event)

      conn = post(conn, ~p"/api/events/#{event.id}/purchase", order: %{})
      response = json_response(conn, 422)

      assert response["errors"]["customer_email"]
      assert response["errors"]["customer_name"]
    end

    test "supports idempotency", %{conn: conn} do
      event = insert(:published_event, %{available_tickets: 10})

      attrs = order_attrs(%{"idempotency_key" => "unique-key-123"})

      conn1 = post(conn, ~p"/api/events/#{event.id}/purchase", order: attrs)
      response1 = json_response(conn1, 201)

      conn2 = post(conn, ~p"/api/events/#{event.id}/purchase", order: attrs)
      response2 = json_response(conn2, 201)

      # Same order returned
      assert response1["data"]["id"] == response2["data"]["id"]

      # Tickets only decremented once
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 8
    end
  end

  describe "POST /api/orders/:id/cancel" do
    test "cancels a confirmed order", %{conn: conn} do
      event = insert(:published_event, %{available_tickets: 8})
      order = insert(:order, %{event: event, quantity: 2, status: "confirmed"})

      conn = post(conn, ~p"/api/orders/#{order.id}/cancel")
      response = json_response(conn, 200)

      assert response["data"]["status"] == "cancelled"

      # Tickets should be returned
      updated_event = Events.get_event(event.id)
      assert updated_event.available_tickets == 10
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = post(conn, ~p"/api/orders/#{Ecto.UUID.generate()}/cancel")
      assert json_response(conn, 404)
    end

    test "returns 422 for non-confirmed orders", %{conn: conn} do
      order = insert(:order, %{status: "cancelled"})

      conn = post(conn, ~p"/api/orders/#{order.id}/cancel")
      assert json_response(conn, 422)
    end
  end
end
