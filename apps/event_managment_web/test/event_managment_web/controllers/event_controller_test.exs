defmodule EventManagmentWeb.EventControllerTest do
  use EventManagmentWeb.ConnCase, async: true

  describe "GET /api/events" do
    test "lists all events", %{conn: conn} do
      event = insert(:event)

      conn = get(conn, ~p"/api/events")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == event.id
    end

    test "filters by status", %{conn: conn} do
      _draft = insert(:event, %{status: "draft"})
      published = insert(:published_event)

      conn = get(conn, ~p"/api/events?status=published")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == published.id
    end

    test "filters upcoming events", %{conn: conn} do
      future = insert(:event)

      _past =
        insert(:event, %{
          date: DateTime.add(DateTime.utc_now(), -1, :day),
          status: "completed"
        })

      conn = get(conn, ~p"/api/events?upcoming=true")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == future.id
    end
  end

  describe "GET /api/events/:id" do
    test "returns event when found", %{conn: conn} do
      event = insert(:event)

      conn = get(conn, ~p"/api/events/#{event.id}")
      response = json_response(conn, 200)

      assert response["data"]["id"] == event.id
      assert response["data"]["name"] == event.name
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = get(conn, ~p"/api/events/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/events" do
    test "creates event with valid data", %{conn: conn} do
      attrs = event_attrs()

      conn = post(conn, ~p"/api/events", event: attrs)
      response = json_response(conn, 201)

      assert response["data"]["name"] == "New Event"
      assert response["data"]["status"] == "draft"
      assert response["data"]["available_tickets"] == 200
    end

    test "returns errors for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/events", event: %{})
      response = json_response(conn, 422)

      assert response["errors"]["name"]
      assert response["errors"]["venue"]
    end
  end

  describe "PUT /api/events/:id" do
    test "updates event with valid data", %{conn: conn} do
      event = insert(:event)

      conn = put(conn, ~p"/api/events/#{event.id}", event: %{name: "Updated Name"})
      response = json_response(conn, 200)

      assert response["data"]["name"] == "Updated Name"
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = put(conn, ~p"/api/events/#{Ecto.UUID.generate()}", event: %{name: "Test"})
      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/events/:id" do
    test "deletes event", %{conn: conn} do
      event = insert(:event)

      conn = delete(conn, ~p"/api/events/#{event.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/events/#{event.id}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/events/:event_id/publish" do
    test "publishes a draft event", %{conn: conn} do
      event = insert(:event, %{status: "draft"})

      conn = post(conn, ~p"/api/events/#{event.id}/publish")
      response = json_response(conn, 200)

      assert response["data"]["status"] == "published"
    end

    test "returns error for already published event", %{conn: conn} do
      event = insert(:published_event)

      conn = post(conn, ~p"/api/events/#{event.id}/publish")
      assert json_response(conn, 422)
    end
  end
end
