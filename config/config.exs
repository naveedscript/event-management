# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :event_managment,
  ecto_repos: [EventManagment.Repo]

config :event_managment_web,
  ecto_repos: [EventManagment.Repo],
  generators: [context_app: :event_managment, binary_id: true]

# Configures the endpoint
config :event_managment_web, EventManagmentWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: EventManagmentWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EventManagment.PubSub,
  live_view: [signing_salt: "/otrLCeX"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban configuration
config :event_managment, Oban,
  repo: EventManagment.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 0 * * *", EventManagment.Workers.EventCompletionJob}
     ]}
  ],
  queues: [default: 10, emails: 5, scheduled: 2]

# Swoosh mailer configuration
config :event_managment, EventManagment.Mailer, adapter: Swoosh.Adapters.Local

# Disable Swoosh API client (we don't need HTTP for Local adapter)
config :swoosh, :api_client, false

# External services - use behaviors for dependency injection
config :event_managment, :email_service, EventManagment.Notifications.EmailService.Swoosh
config :event_managment, :payment_gateway, EventManagment.Payments.Gateway.Stripe

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
