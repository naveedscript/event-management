defmodule EventManagment.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach Oban telemetry handlers for job monitoring
    EventManagment.ObanTelemetry.attach()

    children = [
      EventManagment.Repo,
      {DNSCluster, query: Application.get_env(:event_managment, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EventManagment.PubSub},
      {Finch, name: EventManagment.Finch},
      {Oban, Application.fetch_env!(:event_managment, Oban)},
      {EventManagment.RateLimiter, clean_period: :timer.minutes(1)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EventManagment.Supervisor)
  end
end
