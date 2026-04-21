defmodule PlatformPhx.RegentStakingTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.RegentStaking

  defmodule RuntimeConfigStub do
    def regent_staking_contract_address, do: "0x9999999999999999999999999999999999999999"
    def regent_staking_rpc_url, do: "https://base-rpc.example"
    def regent_staking_chain_id, do: 8453
    def regent_staking_chain_label, do: "Base"
  end

  defmodule EthereumStub do
    def json_rpc(_url, "eth_call", _params), do: {:error, "upstream offline"}
  end

  setup do
    original = Application.get_env(:platform_phx, :regent_staking, [])

    Application.put_env(
      :platform_phx,
      :regent_staking,
      ethereum_module: EthereumStub,
      runtime_config_module: RuntimeConfigStub
    )

    on_exit(fn ->
      Application.put_env(:platform_phx, :regent_staking, original)
    end)

    :ok
  end

  test "overview returns unavailable when rpc reads fail" do
    assert {:error, :unavailable} = RegentStaking.overview(nil)
  end
end
