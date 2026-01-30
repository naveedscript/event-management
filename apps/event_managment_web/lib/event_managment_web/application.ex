defmodule EventManagmentWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EventManagmentWeb.Telemetry,
      # Start a worker by calling: EventManagmentWeb.Worker.start_link(arg)
      # {EventManagmentWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      EventManagmentWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventManagmentWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EventManagmentWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
