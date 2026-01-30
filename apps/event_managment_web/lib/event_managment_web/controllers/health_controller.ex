defmodule EventManagmentWeb.HealthController do
  @moduledoc """
  Health check endpoint for monitoring and load balancer probes.

  Returns system health status including:
  - Database connectivity
  - Oban job queue status
  - System timestamp
  """
  use EventManagmentWeb, :controller

  alias EventManagment.Repo

  @doc """
  Performs health checks and returns system status.

  ## Response Codes
  - 200 OK - All systems operational
  - 503 Service Unavailable - One or more systems unhealthy

  ## Response Body
  ```json
  {
    "status": "ok" | "degraded" | "unhealthy",
    "timestamp": "2024-01-01T00:00:00Z",
    "checks": {
      "database": "ok" | "error",
      "oban": "ok" | "error"
    }
  }
  ```
  """
  def check(conn, _params) do
    checks = %{
      database: check_database(),
      oban: check_oban()
    }

    status = determine_status(checks)
    http_status = if status == "ok", do: :ok, else: :service_unavailable

    conn
    |> put_status(http_status)
    |> json(%{
      status: status,
      timestamp: DateTime.utc_now(),
      checks: checks
    })
  end

  defp check_database do
    case Repo.query("SELECT 1") do
      {:ok, _} -> "ok"
      {:error, _} -> "error"
    end
  rescue
    _ -> "error"
  end

  defp check_oban do
    case Oban.check_queue(:default) do
      %{paused: false} -> "ok"
      %{paused: true} -> "paused"
      _ -> "error"
    end
  rescue
    _ -> "error"
  end

  defp determine_status(checks) do
    cond do
      Enum.all?(checks, fn {_k, v} -> v == "ok" end) -> "ok"
      checks.database == "error" -> "unhealthy"
      true -> "degraded"
    end
  end
end
