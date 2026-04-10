import Config

pg_username = System.get_env("PGUSER") || System.get_env("USER") || "postgres"
pg_password = System.get_env("PGPASSWORD")
pg_hostname = System.get_env("PGHOST") || "localhost"

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :web, Web.Repo,
  username: pg_username,
  password: pg_password,
  hostname: pg_hostname,
  database: "web_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :web,
  ethereum_adapter: Web.TestEthereumAdapter,
  opensea_client: Web.TestOpenSeaClient

config :web, :token_metadata_root, Path.expand("../priv/metadata", __DIR__)

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :web, WebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "TgX+zcJTgS+fZ7WpfLZl5A+oda0b8OeYzwge39+575WkMLHtPa0wrqgEY7+EAhPF",
  server: false

config :web, WebWeb.PrometheusExporter, enabled: false

config :web, Oban,
  repo: Web.Repo,
  testing: :manual,
  queues: false,
  plugins: false

# In test we don't send emails
config :web, Web.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
