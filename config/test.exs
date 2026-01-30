import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :event_managment, EventManagment.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_managment_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :event_managment_web, EventManagmentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dhCVzz11iYXQ2vhqIKZQ492zq4/vxSsH85ywSwvFIGrvVDVjNqtawmnXDPWqrEi2",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban inline mode for testing
config :event_managment, Oban, testing: :inline

# Use mock implementations for external services in tests
config :event_managment, :email_service, EventManagment.Notifications.EmailService.Mock
config :event_managment, :payment_gateway, EventManagment.Payments.Gateway.Mock

# Mark as test environment for rate limiter bypass
config :event_managment, :env, :test
