defmodule PlatformPhx.Beta.DoctorTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Beta.Doctor

  @operator_wallet "0x1111111111111111111111111111111111111111"
  @staking_contract "0x2222222222222222222222222222222222222222"

  setup do
    previous_agent_formation_enabled =
      Application.get_env(:platform_phx, :agent_formation_enabled)

    previous_agent_formation_enabled_env = System.get_env("AGENT_FORMATION_ENABLED")

    previous_staking_validator =
      Application.get_env(:platform_phx, :beta_doctor_staking_validator)

    Application.put_env(:platform_phx, :agent_formation_enabled, false)

    Application.put_env(
      :platform_phx,
      :beta_doctor_staking_validator,
      __MODULE__.StakingValidator
    )

    System.delete_env("AGENT_FORMATION_ENABLED")

    on_exit(fn ->
      restore_app_env(:platform_phx, :agent_formation_enabled, previous_agent_formation_enabled)
      restore_app_env(:platform_phx, :beta_doctor_staking_validator, previous_staking_validator)
      restore_system_env("AGENT_FORMATION_ENABLED", previous_agent_formation_enabled_env)
    end)

    :ok
  end

  test "passes with the required beta values and marks paused company opening as not included" do
    result = Doctor.run(env: ready_env())

    assert result.status == "pass"
    assert check_status(result, "database") == "pass"
    assert check_status(result, "status_constraint_preflight") == "pass"
    assert check_status(result, "direct_database_url") == "pass"
    assert check_status(result, "cache") == "pass"
    assert check_status(result, "regent_staking_chain") == "pass"
    assert check_status(result, "hosted_company_opening") == "not_included"
  end

  test "blocks when staking points away from Base mainnet" do
    env = Map.put(ready_env(), "REGENT_STAKING_CHAIN_ID", "84532")

    result = Doctor.run(env: env)

    assert result.status == "blocked"
    assert check_status(result, "regent_staking_chain") == "blocked"
  end

  test "blocks when staking rpc is only present through the general Base RPC setting" do
    env =
      ready_env()
      |> Map.delete("REGENT_STAKING_RPC_URL")
      |> Map.put("BASE_RPC_URL", "https://base.example")

    result = Doctor.run(env: env)

    assert result.status == "blocked"
    assert check_status(result, "regent_staking_rpc") == "blocked"
  end

  test "blocks when staking rpc cannot prove the configured contract" do
    result =
      Doctor.run(env: ready_env(), staking_validator: fn _attrs -> {:error, :rpc_unavailable} end)

    assert result.status == "blocked"
    assert check_status(result, "regent_staking_rpc") == "blocked"
  end

  test "blocks when release migrations do not have a direct database URL" do
    env = Map.delete(ready_env(), "DATABASE_DIRECT_URL")

    result = Doctor.run(env: env)

    assert result.status == "blocked"
    assert check_status(result, "direct_database_url") == "blocked"
  end

  test "uses the supplied env when hosted company opening is enabled" do
    env = Map.put(ready_env(), "AGENT_FORMATION_ENABLED", "true")

    result = Doctor.run(env: env)

    assert result.status == "blocked"
    assert check_status(result, "stripe_webhook") == "pass"
    assert check_status(result, "hosted_company_opening") == "blocked"
  end

  test "does not print secret values in check messages" do
    secret = "whsec_super_secret"
    result = Doctor.run(env: Map.put(ready_env(), "STRIPE_WEBHOOK_SECRET", secret))

    result.checks
    |> Enum.map(& &1.message)
    |> Enum.each(fn message ->
      refute message =~ secret
    end)
  end

  defp ready_env do
    %{
      "PLATFORM_BETA_HOST" => "https://platform.example",
      "DATABASE_DIRECT_URL" => "ecto://user:pass@db.example/platform",
      "SIWA_SERVER_BASE_URL" => "https://siwa.example",
      "VITE_PRIVY_APP_ID" => "privy-app",
      "VITE_PRIVY_APP_CLIENT_ID" => "privy-client",
      "PRIVY_VERIFICATION_KEY" => "privy-key",
      "REGENT_STAKING_CONTRACT_ADDRESS" => @staking_contract,
      "REGENT_STAKING_RPC_URL" => "https://base.example",
      "REGENT_STAKING_CHAIN_ID" => "8453",
      "REGENT_STAKING_OPERATOR_WALLETS" => @operator_wallet,
      "STRIPE_WEBHOOK_SECRET" => "whsec_test"
    }
  end

  defmodule StakingValidator do
    def validate_rpc(_attrs), do: :ok
  end

  defp check_status(result, name) do
    result.checks
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:status)
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)
end
