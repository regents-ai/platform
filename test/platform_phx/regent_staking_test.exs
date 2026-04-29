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

  defmodule HealthyEthereumStub do
    def json_rpc(_url, "eth_chainId", []), do: {:ok, "0x2105"}

    def json_rpc(_url, "eth_call", [%{data: "0x8da5cb5b"}, "latest"]) do
      {:ok, "0x0000000000000000000000001111111111111111111111111111111111111111"}
    end
  end

  defmodule WrongChainEthereumStub do
    def json_rpc(_url, "eth_chainId", []), do: {:ok, "0x14a34"}
    def json_rpc(_url, "eth_call", _params), do: {:ok, "0x"}
  end

  defmodule MissingContractEthereumStub do
    def json_rpc(_url, "eth_chainId", []), do: {:ok, "0x2105"}
    def json_rpc(_url, "eth_call", _params), do: {:error, "missing contract"}
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

  test "validate_rpc proves the configured chain and staking contract" do
    configure_ethereum(HealthyEthereumStub)

    assert :ok =
             RegentStaking.validate_rpc(%{
               rpc_url: "https://base-rpc.example",
               chain_id: 8453,
               contract_address: "0x9999999999999999999999999999999999999999"
             })
  end

  test "validate_rpc rejects the wrong chain" do
    configure_ethereum(WrongChainEthereumStub)

    assert {:error, {:wrong_chain_id, observed: 84_532, expected: 8_453}} =
             RegentStaking.validate_rpc(%{
               rpc_url: "https://base-rpc.example",
               chain_id: 8453,
               contract_address: "0x9999999999999999999999999999999999999999"
             })
  end

  test "validate_rpc rejects an unreachable contract" do
    configure_ethereum(MissingContractEthereumStub)

    assert {:error, :upstream_unavailable} =
             RegentStaking.validate_rpc(%{
               rpc_url: "https://base-rpc.example",
               chain_id: 8453,
               contract_address: "0x9999999999999999999999999999999999999999"
             })
  end

  defp configure_ethereum(module) do
    Application.put_env(
      :platform_phx,
      :regent_staking,
      ethereum_module: module,
      runtime_config_module: RuntimeConfigStub
    )
  end
end
