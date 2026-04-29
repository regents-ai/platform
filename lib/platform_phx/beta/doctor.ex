defmodule PlatformPhx.Beta.Doctor do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig

  @base_mainnet_chain_id 8_453
  @evm_address_pattern ~r/^0x[0-9a-fA-F]{40}$/

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    env = Keyword.get(opts, :env, &System.get_env/1)
    staking_validator = staking_validator(opts)

    checks = [
      database_check(),
      status_constraint_preflight_check(),
      direct_database_check(env),
      cache_check(),
      public_host_check(env),
      siwa_check(env),
      privy_check(env),
      staking_contract_check(env),
      staking_rpc_check(env, staking_validator),
      staking_chain_check(env),
      staking_operator_wallets_check(env),
      stripe_webhook_check(env),
      hosted_company_opening_check(env)
    ]

    %{
      generated_at: now_iso(),
      status: overall_status(checks),
      checks: checks
    }
  end

  defp database_check do
    with :ok <- ensure_repo_started(),
         {:ok, _result} <- Repo.query("select 1", []) do
      check("database", "pass", "Database is reachable.")
    else
      _reason ->
        check("database", "blocked", "Database is not reachable.")
    end
  end

  defp status_constraint_preflight_check do
    case PlatformPhx.Beta.StatusConstraintPreflight.run() do
      {:ok, []} ->
        check("status_constraint_preflight", "pass", "Current status values are migration-ready.")

      {:ok, invalid_statuses} ->
        check(
          "status_constraint_preflight",
          "blocked",
          "Clean invalid status values before running release migrations.",
          invalid_statuses: invalid_statuses
        )

      {:error, reason} ->
        check(
          "status_constraint_preflight",
          "blocked",
          "Status preflight could not read the database.",
          reason: inspect(reason)
        )
    end
  end

  defp direct_database_check(env) do
    if present?(env_value(env, "DATABASE_DIRECT_URL")) do
      check("direct_database_url", "pass", "Release migration database URL is configured.")
    else
      check(
        "direct_database_url",
        "blocked",
        "Set DATABASE_DIRECT_URL before running release migrations."
      )
    end
  end

  defp cache_check do
    case PlatformPhx.LocalCache.status() do
      :ready -> check("cache", "pass", "Local cache is ready.")
      {:error, _reason} -> check("cache", "blocked", "Local cache is not ready.")
    end
  end

  defp public_host_check(env) do
    if present?(env_value(env, "PLATFORM_BETA_HOST") || env_value(env, "PHX_HOST")) do
      check("public_host", "pass", "Public host is configured.")
    else
      check("public_host", "blocked", "Set PHX_HOST or PLATFORM_BETA_HOST before beta deploy.")
    end
  end

  defp siwa_check(env) do
    if present?(env_value(env, "SIWA_SERVER_BASE_URL")) do
      check("siwa", "pass", "Signed agent verification is configured.")
    else
      check("siwa", "blocked", "Set SIWA_SERVER_BASE_URL before beta deploy.")
    end
  end

  defp privy_check(env) do
    required = ~w(VITE_PRIVY_APP_ID VITE_PRIVY_APP_CLIENT_ID PRIVY_VERIFICATION_KEY)
    missing = Enum.reject(required, &present?(env_value(env, &1)))

    if missing == [] do
      check("privy", "pass", "Human sign-in is configured.")
    else
      check("privy", "blocked", "Set Privy sign-in values before beta deploy.",
        missing_env: missing
      )
    end
  end

  defp staking_contract_check(env) do
    address = env_value(env, "REGENT_STAKING_CONTRACT_ADDRESS")

    cond do
      valid_address?(address) ->
        check("regent_staking_contract", "pass", "$REGENT staking contract is configured.")

      present?(address) ->
        check(
          "regent_staking_contract",
          "blocked",
          "$REGENT staking contract address is not a valid wallet address."
        )

      true ->
        check("regent_staking_contract", "blocked", "Set REGENT_STAKING_CONTRACT_ADDRESS.")
    end
  end

  defp staking_rpc_check(env, validator) do
    rpc_url = env_value(env, "REGENT_STAKING_RPC_URL")
    contract_address = env_value(env, "REGENT_STAKING_CONTRACT_ADDRESS")

    with true <- present?(rpc_url) || :missing_rpc,
         true <- valid_address?(contract_address) || :invalid_contract,
         {:ok, chain_id} <- parse_integer(env_value(env, "REGENT_STAKING_CHAIN_ID")),
         :ok <-
           validate_staking_rpc(validator, %{
             rpc_url: rpc_url,
             contract_address: String.downcase(contract_address),
             chain_id: chain_id
           }) do
      check("regent_staking_rpc", "pass", "$REGENT staking RPC reaches the configured contract.")
    else
      :missing_rpc ->
        check("regent_staking_rpc", "blocked", "Set REGENT_STAKING_RPC_URL for beta staking.")

      :invalid_contract ->
        check(
          "regent_staking_rpc",
          "blocked",
          "Set a valid REGENT_STAKING_CONTRACT_ADDRESS before checking the staking RPC."
        )

      :error ->
        check(
          "regent_staking_rpc",
          "blocked",
          "Set REGENT_STAKING_CHAIN_ID before checking the staking RPC."
        )

      {:error, reason} ->
        check(
          "regent_staking_rpc",
          "blocked",
          "$REGENT staking RPC could not prove the configured Base contract.",
          reason: format_staking_rpc_reason(reason)
        )
    end
  end

  defp staking_chain_check(env) do
    case parse_integer(env_value(env, "REGENT_STAKING_CHAIN_ID")) do
      {:ok, @base_mainnet_chain_id} ->
        check("regent_staking_chain", "pass", "$REGENT staking is pointed at Base mainnet.")

      {:ok, chain_id} ->
        check(
          "regent_staking_chain",
          "blocked",
          "$REGENT staking must point at Base mainnet for beta.",
          current_chain_id: chain_id,
          expected_chain_id: @base_mainnet_chain_id
        )

      :error ->
        check(
          "regent_staking_chain",
          "blocked",
          "Set REGENT_STAKING_CHAIN_ID to Base mainnet before beta deploy.",
          expected_chain_id: @base_mainnet_chain_id
        )
    end
  end

  defp staking_operator_wallets_check(env) do
    wallets =
      env
      |> env_value("REGENT_STAKING_OPERATOR_WALLETS")
      |> to_string()
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if wallets != [] and Enum.all?(wallets, &valid_address?/1) do
      check("regent_staking_operators", "pass", "$REGENT operator wallets are configured.")
    else
      check(
        "regent_staking_operators",
        "blocked",
        "Set REGENT_STAKING_OPERATOR_WALLETS before beta deploy."
      )
    end
  end

  defp stripe_webhook_check(env) do
    cond do
      present?(env_value(env, "STRIPE_WEBHOOK_SECRET")) ->
        check("stripe_webhook", "pass", "Stripe webhook signing is configured.")

      formation_enabled?(env) ->
        check("stripe_webhook", "blocked", "Set STRIPE_WEBHOOK_SECRET before enabling billing.")

      true ->
        check(
          "stripe_webhook",
          "not_included",
          "Stripe billing webhooks are not included while hosted company opening is paused."
        )
    end
  end

  defp hosted_company_opening_check(env) do
    if formation_enabled?(env) do
      required = ~w(STRIPE_SECRET_KEY STRIPE_BILLING_PRICING_PLAN_ID)
      missing = Enum.reject(required, &present?(env_value(env, &1)))
      sprite_ready? = present?(env_value(env, "SPRITES_API_TOKEN_FILE"))

      cond do
        missing == [] and sprite_ready? ->
          check("hosted_company_opening", "pass", "Hosted company opening is configured.")

        true ->
          check(
            "hosted_company_opening",
            "blocked",
            "Hosted company opening is enabled but not fully configured.",
            missing_env: missing ++ if(sprite_ready?, do: [], else: ["SPRITES_API_TOKEN_FILE"])
          )
      end
    else
      check(
        "hosted_company_opening",
        "not_included",
        "Hosted company opening stays visible but unavailable for beta."
      )
    end
  end

  defp overall_status(checks) do
    if Enum.any?(checks, &(&1.status == "blocked")), do: "blocked", else: "pass"
  end

  defp check(name, status, message, extra \\ []) do
    extra
    |> Map.new()
    |> Map.merge(%{name: name, status: status, message: message})
  end

  defp env_value(env, name) when is_function(env, 1), do: env.(name)
  defp env_value(env, name) when is_map(env), do: Map.get(env, name)

  defp env_value(env, name) when is_list(env) do
    env
    |> Map.new()
    |> Map.get(name)
  end

  defp staking_validator(opts) do
    Keyword.get(opts, :staking_validator) ||
      Application.get_env(
        :platform_phx,
        :beta_doctor_staking_validator,
        PlatformPhx.RegentStaking
      )
  end

  defp validate_staking_rpc(validator, attrs) when is_function(validator, 1),
    do: validator.(attrs)

  defp validate_staking_rpc(validator, attrs), do: validator.validate_rpc(attrs)

  defp format_staking_rpc_reason({:wrong_chain_id, details}), do: inspect(Map.new(details))
  defp format_staking_rpc_reason(reason), do: inspect(reason)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp valid_address?(value) when is_binary(value), do: Regex.match?(@evm_address_pattern, value)
  defp valid_address?(_value), do: false

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> {:ok, parsed}
      _other -> :error
    end
  end

  defp parse_integer(_value), do: :error

  defp formation_enabled?(env) do
    case env_value(env, "AGENT_FORMATION_ENABLED") do
      value when value in ["1", "true", "TRUE", "yes", "YES"] -> true
      value when value in ["0", "false", "FALSE", "no", "NO"] -> false
      _value -> RuntimeConfig.agent_formation_enabled?()
    end
  end

  defp ensure_repo_started do
    _ = Application.ensure_all_started(:telemetry)
    _ = Application.ensure_all_started(:postgrex)
    _ = Application.ensure_all_started(:ecto_sql)

    case Process.whereis(Repo) do
      nil ->
        case Repo.start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, _reason} = error -> error
        end

      _pid ->
        :ok
    end
  end

  defp now_iso do
    PlatformPhx.Clock.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
