defmodule EventManagmentWeb.Plugs.RateLimiterTest do
  use EventManagmentWeb.ConnCase, async: false

  alias EventManagmentWeb.Plugs.RateLimiter

  setup do
    # Enable rate limiting for this test (normally disabled in test env)
    original_env = Application.get_env(:event_managment, :env)
    original_config = Application.get_env(:event_managment_web, RateLimiter)

    Application.put_env(:event_managment, :env, :dev)

    on_exit(fn ->
      Application.put_env(:event_managment, :env, original_env)
      if original_config do
        Application.put_env(:event_managment_web, RateLimiter, original_config)
      else
        Application.delete_env(:event_managment_web, RateLimiter)
      end
    end)

    :ok
  end

  describe "rate limiting" do
    test "allows requests under the limit", %{conn: conn} do
      ip = {192, 168, 1, unique_ip()}
      conn = conn |> Map.put(:remote_ip, ip)

      conn = RateLimiter.call(conn, [])

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") != []
    end

    test "blocks requests over the limit", %{conn: _conn} do
      ip = {192, 168, 1, unique_ip()}

      # Configure very low limit for testing
      Application.put_env(:event_managment_web, RateLimiter, general_limit: 2, general_scale_ms: 60_000)

      # First two requests should succeed
      conn1 = build_conn_with_ip(ip) |> RateLimiter.call([])
      refute conn1.halted

      conn2 = build_conn_with_ip(ip) |> RateLimiter.call([])
      refute conn2.halted

      # Third request should be rate limited
      conn3 = build_conn_with_ip(ip) |> RateLimiter.call([])
      assert conn3.halted
      assert conn3.status == 429
    end

    test "uses stricter limits for purchase endpoints", %{conn: _conn} do
      ip = {192, 168, 1, unique_ip()}

      Application.put_env(:event_managment_web, RateLimiter, purchase_limit: 1, purchase_scale_ms: 60_000)

      conn1 = build_conn_with_ip(ip) |> Map.put(:request_path, "/api/events/123/purchase") |> RateLimiter.call([])
      refute conn1.halted

      conn2 = build_conn_with_ip(ip) |> Map.put(:request_path, "/api/events/123/purchase") |> RateLimiter.call([])
      assert conn2.halted
      assert conn2.status == 429
    end

    test "uses X-Forwarded-For header when present", %{conn: conn} do
      forwarded_ip = "203.0.113.#{unique_ip()}"

      conn =
        conn
        |> Map.put(:remote_ip, {127, 0, 0, 1})
        |> Plug.Conn.put_req_header("x-forwarded-for", forwarded_ip)

      conn = RateLimiter.call(conn, [])
      refute conn.halted
    end

    test "rate limits are per-IP" do
      Application.put_env(:event_managment_web, RateLimiter, general_limit: 1, general_scale_ms: 60_000)

      ip1 = {10, 0, 0, unique_ip()}
      ip2 = {10, 0, 0, unique_ip()}

      conn1 = build_conn_with_ip(ip1) |> RateLimiter.call([])
      refute conn1.halted

      conn2 = build_conn_with_ip(ip2) |> RateLimiter.call([])
      refute conn2.halted

      # Second request from ip1 should be blocked
      conn3 = build_conn_with_ip(ip1) |> RateLimiter.call([])
      assert conn3.halted
    end
  end

  defp build_conn_with_ip(ip) do
    Phoenix.ConnTest.build_conn()
    |> Map.put(:remote_ip, ip)
    |> Plug.Conn.fetch_query_params()
    |> Map.update!(:params, &Map.put(&1, "_format", "json"))
  end

  defp unique_ip do
    System.unique_integer([:positive]) |> rem(255)
  end
end
