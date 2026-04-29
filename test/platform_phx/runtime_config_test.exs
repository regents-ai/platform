defmodule PlatformPhx.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.RuntimeConfig

  @env_names ~w(
    SIWA_SERVER_BASE_URL
    REGENT_STAKING_CONTRACT_ADDRESS
    REGENT_STAKING_RPC_URL
    REGENT_STAKING_CHAIN_ID
    REGENT_STAKING_CHAIN_LABEL
    BASE_RPC_URL
  )

  setup do
    previous_env = Map.new(@env_names, &{&1, System.get_env(&1)})
    previous_validation = Application.get_env(:platform_phx, :validate_enabled_surfaces_on_boot)
    previous_formation = Application.get_env(:platform_phx, :agent_formation_enabled)
    previous_regent_staking = Application.get_env(:platform_phx, :regent_staking)

    Enum.each(@env_names, &System.delete_env/1)
    Application.put_env(:platform_phx, :validate_enabled_surfaces_on_boot, true)
    Application.put_env(:platform_phx, :agent_formation_enabled, false)
    Application.put_env(:platform_phx, :regent_staking, ethereum_module: __MODULE__.EthereumStub)

    on_exit(fn ->
      Enum.each(previous_env, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)

      restore_app_env(:platform_phx, :validate_enabled_surfaces_on_boot, previous_validation)
      restore_app_env(:platform_phx, :agent_formation_enabled, previous_formation)
      restore_app_env(:platform_phx, :regent_staking, previous_regent_staking)
    end)

    :ok
  end

  test "production surface validation requires the explicit staking rpc setting" do
    System.put_env("SIWA_SERVER_BASE_URL", "https://siwa.example")

    System.put_env(
      "REGENT_STAKING_CONTRACT_ADDRESS",
      "0x2222222222222222222222222222222222222222"
    )

    System.put_env("REGENT_STAKING_CHAIN_ID", "8453")
    System.put_env("REGENT_STAKING_CHAIN_LABEL", "Base")
    System.put_env("BASE_RPC_URL", "https://base.example")

    assert_raise RuntimeError, ~r/REGENT_STAKING_RPC_URL/, fn ->
      RuntimeConfig.validate_enabled_surfaces!()
    end

    System.put_env("REGENT_STAKING_RPC_URL", "https://staking-rpc.example")

    assert :ok = RuntimeConfig.validate_enabled_surfaces!()
  end

  defmodule EthereumStub do
    def json_rpc(_url, "eth_chainId", []), do: {:ok, "0x2105"}

    def json_rpc(_url, "eth_call", [%{data: "0x8da5cb5b"}, "latest"]) do
      {:ok, "0x0000000000000000000000001111111111111111111111111111111111111111"}
    end
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
