# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :platform_phx,
  ecto_repos: [PlatformPhx.Repo],
  dragonfly_enabled: true,
  dragonfly_host: "localhost",
  dragonfly_port: 6379,
  generators: [timestamp_type: :utc_datetime]

config :platform_phx, PlatformPhxWeb.BrowserSecurity, env: config_env()

# Configure the endpoint
config :platform_phx, PlatformPhxWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PlatformPhxWeb.ErrorHTML, json: PlatformPhxWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PlatformPhx.PubSub,
  live_view: [signing_salt: "eGS39NaF"]

config :platform_phx, PlatformPhxWeb.PrometheusExporter,
  enabled: true,
  ip: {127, 0, 0, 1},
  port: 9568

config :platform_phx, Oban,
  repo: PlatformPhx.Repo,
  queues: [agent_formation: 1, billing: 5, runtime_metering: 1, runtime_registry: 2, work_runs: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 86_400},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorker}
     ]}
  ]

config :platform_phx, PlatformPhx.Xmtp,
  rooms: [
    %{
      key: "platform_agents",
      name: "Platform Agents",
      description: "A room reserved for agent identities.",
      app_data: "platform-agents",
      agent_private_key: nil,
      moderator_wallets: [],
      capacity: 200,
      presence_timeout_ms: :timer.minutes(2),
      presence_check_interval_ms: :timer.seconds(30),
      policy_options: %{
        allowed_kinds: [:agent],
        required_claims: %{}
      }
    }
  ]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :platform_phx, PlatformPhx.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  platform_phx: [
    args:
      ~w(js/app.ts --bundle --splitting --format=esm --target=es2022 --outdir=../priv/static/assets/js --chunk-names=chunks/[name]-[hash] --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  platform_phx: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
