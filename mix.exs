defmodule PlatformPhx.MixProject do
  use Mix.Project

  def project do
    [
      app: :platform_phx,
      version: "0.1.0",
      elixir: "~> 1.19.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PlatformPhx.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, "contract.validate": :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.4"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:joken, "~> 2.6"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:xmtp_elixir_sdk, path: "../elixir-utils/xmtp"},
      {:keccak_ex, "~> 0.4.2"},
      {:ex_secp256k1, "~> 0.8.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:oban, "~> 2.19"},
      {:regent_cache, path: "../elixir-utils/cache"},
      {:ens_elixir, path: "../elixir-utils/ens"},
      {:agent_world, path: "../elixir-utils/world/agentbook"},
      {:yamerl, "~> 0.10", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: [
        "deps.get",
        "ecto.setup",
        "assets.setup",
        "public.sync",
        "assets.build"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test --max-cases 8"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "public.sync": [&sync_public_assets/1],
      "assets.build": ["compile", "public.sync", "tailwind platform_phx", "esbuild platform_phx"],
      "corpus.build": [&build_corpus/1],
      "assets.deploy": [
        "corpus.build",
        "public.sync",
        "tailwind platform_phx --minify",
        "esbuild platform_phx --minify",
        "phx.digest"
      ],
      "contract.validate": [
        "test --max-cases 1 test/platform_phx_web/controllers/contract_validation_test.exs"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "contract.validate",
        &reenable_test_task/1,
        "test"
      ]
    ]
  end

  defp reenable_test_task(_args) do
    Mix.Task.reenable("test")
  end

  defp sync_public_assets(_args) do
    source = Path.expand("assets/public", __DIR__)
    destination = Path.expand("priv/static/images", __DIR__)

    File.mkdir_p!(destination)

    Enum.each(File.ls!(source), fn entry ->
      source_path = Path.join(source, entry)
      destination_path = Path.join(destination, entry)

      File.rm_rf!(destination_path)

      case File.cp_r(source_path, destination_path) do
        {:ok, _copied} ->
          :ok

        {:error, reason, file} ->
          Mix.raise("Failed to sync public assets from #{file}: #{inspect(reason)}")
      end
    end)
  end

  defp build_corpus(_args) do
    learn_site_path = Path.expand("learn-site", __DIR__)

    {_, status} =
      System.cmd("npm", ["ci"], cd: learn_site_path, into: IO.stream())

    if status != 0 do
      Mix.raise("Failed to install Regents corpus dependencies")
    end

    {_, status} =
      System.cmd("npm", ["run", "build"], cd: learn_site_path, into: IO.stream())

    if status != 0 do
      Mix.raise("Failed to build Regents corpus")
    end
  end
end
