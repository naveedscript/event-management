defmodule EventManagmentWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.

  Limits requests per IP address to prevent abuse.

  ## Configuration

  Configure in `config/config.exs`:

      config :event_managment_web, EventManagmentWeb.Plugs.RateLimiter,
        general_limit: 100,        # requests per window
        general_scale_ms: 60_000,  # 1 minute
        purchase_limit: 10,
        purchase_scale_ms: 60_000

  ## Default Limits

  - General API endpoints: 100 requests per minute
  - Purchase endpoints: 10 requests per minute

  ## Response Headers

  When rate limited, returns:
  - `429 Too Many Requests` status code
  - `Retry-After` header with seconds until reset

  ## Bypass

  Rate limiting is disabled when `:env` is set to `:test` in config.
  """
  import Plug.Conn

  alias EventManagment.RateLimiter

  @default_general_limit 100
  @default_general_scale :timer.minutes(1)
  @default_purchase_limit 10
  @default_purchase_scale :timer.minutes(1)

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:event_managment, :env) == :test do
      conn
    else
      check_rate_limit(conn)
    end
  end

  defp check_rate_limit(conn) do
    ip = get_client_ip(conn)
    {limit, scale} = get_limits(conn)
    key = rate_limit_key(conn, ip)

    case RateLimiter.hit(key, scale, limit) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(max(0, limit - count)))

      {:deny, retry_after_ms} ->
        retry_after_sec = div(retry_after_ms, 1000)

        conn
        |> put_resp_header("retry-after", to_string(retry_after_sec))
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.put_view(json: EventManagmentWeb.ErrorJSON)
        |> Phoenix.Controller.render(:error, message: "Rate limit exceeded. Please try again later.")
        |> halt()
    end
  end

  defp rate_limit_key(conn, ip) do
    if purchase_endpoint?(conn) do
      "api:purchase:#{ip}"
    else
      "api:general:#{ip}"
    end
  end

  defp get_limits(conn) do
    config = Application.get_env(:event_managment_web, __MODULE__, [])

    if purchase_endpoint?(conn) do
      limit = Keyword.get(config, :purchase_limit, @default_purchase_limit)
      scale = Keyword.get(config, :purchase_scale_ms, @default_purchase_scale)
      {limit, scale}
    else
      limit = Keyword.get(config, :general_limit, @default_general_limit)
      scale = Keyword.get(config, :general_scale_ms, @default_general_scale)
      {limit, scale}
    end
  end

  defp purchase_endpoint?(conn) do
    # Match routes that end with /purchase
    conn.request_path =~ ~r"/purchase$"
  end

  defp get_client_ip(conn) do
    # Check X-Forwarded-For header first (for load balancer scenarios)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> hd()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
