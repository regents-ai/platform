defmodule PlatformPhx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        PlatformPhxWeb.Telemetry,
        PlatformPhx.Repo,
        PlatformPhx.RateLimiter,
        {Oban, Application.fetch_env!(:platform_phx, Oban)},
        {DNSCluster, query: Application.get_env(:platform_phx, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: PlatformPhx.PubSub},
        PlatformPhx.Xmtp,
        # Start a worker by calling: PlatformPhx.Worker.start_link(arg)
        # {PlatformPhx.Worker, arg},
        # Start to serve requests, typically the last entry
        PlatformPhxWeb.Endpoint
      ]
      |> maybe_add_dragonfly()
      |> maybe_add_sprite_control_secret()
      |> maybe_add_prometheus_exporter()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PlatformPhx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlatformPhxWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_add_prometheus_exporter(children) do
    config = Application.get_env(:platform_phx, PlatformPhxWeb.PrometheusExporter, [])

    if Keyword.get(config, :enabled, true) do
      exporter_child =
        {Bandit,
         plug: PlatformPhxWeb.PrometheusExporter,
         scheme: :http,
         ip: Keyword.fetch!(config, :ip),
         port: Keyword.fetch!(config, :port),
         startup_log: false}

      children ++ [exporter_child]
    else
      children
    end
  end

  defp maybe_add_sprite_control_secret(children) do
    config =
      Application.get_env(:platform_phx, PlatformPhx.OperatorSecrets.SpriteControlSecret, [])

    cond do
      is_binary(Keyword.get(config, :token)) and Keyword.get(config, :token) != "" ->
        [PlatformPhx.OperatorSecrets.SpriteControlSecret | children]

      is_binary(PlatformPhx.RuntimeConfig.sprites_api_token_file()) ->
        [PlatformPhx.OperatorSecrets.SpriteControlSecret | children]

      true ->
        children
    end
  end

  defp maybe_add_dragonfly(children) do
    if RegentCache.Dragonfly.enabled?(:platform_phx) do
      children ++ [RegentCache.Dragonfly.child_spec(:platform_phx)]
    else
      children
    end
  end
end
