defmodule PlatformPhx.AgentPlatform.EnsTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Ens
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.Repo
  alias PlatformPhx.TestEthereumRpcClient

  @wallet "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @registry "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432"
  @registrar "0x3333333333333333333333333333333333333333"
  @owner "0x4444444444444444444444444444444444444444"
  @signer "0x1111111111111111111111111111111111111111"

  defmodule RpcReady do
    def eth_call(_rpc_url, to, data) do
      case {String.downcase(to), data} do
        {"0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e", "0x0178b8bf" <> _node} ->
          {:ok, address_word("0x226159d592e2b063810a10ebf6dcbada94ed68b8")}

        {"0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e", "0x02571be3" <> _node} ->
          {:ok, address_word("0x1111111111111111111111111111111111111111")}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x59d1d43c" <> _rest} ->
          {:ok, encode_string("")}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x01ffc9a7" <> "59d1d43c" <> _padding} ->
          {:ok, bool_word(true)}

        {"0x8004a169fb4a3325136eb29fa0ceb6d2e539a432", "0x6352211e" <> _rest} ->
          {:ok, address_word("0x1111111111111111111111111111111111111111")}

        {"0x8004a169fb4a3325136eb29fa0ceb6d2e539a432", "0x081812fc" <> _rest} ->
          {:ok, address_word("0x0000000000000000000000000000000000000000")}

        {"0x8004a169fb4a3325136eb29fa0ceb6d2e539a432", "0xc87b56dd" <> _rest} ->
          {:ok,
           encode_string(
             "data:application/json," <>
               URI.encode_www_form(
                 Jason.encode!(%{
                   "type" => "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
                   "name" => "Demo Agent",
                   "services" => [%{"name" => "ENS", "endpoint" => "old.eth", "version" => "v1"}]
                 })
               )
           )}

        {"0x8004a169fb4a3325136eb29fa0ceb6d2e539a432", "0xe985e9c5" <> _rest} ->
          {:ok, bool_word(false)}
      end
    end

    defp bool_word(true), do: "0x" <> String.pad_leading("1", 64, "0")
    defp bool_word(false), do: "0x" <> String.duplicate("0", 64)

    defp address_word(address) do
      "0x" <>
        String.pad_leading(String.replace_prefix(String.downcase(address), "0x", ""), 64, "0")
    end

    defp encode_string(value) do
      hex = Base.encode16(value, case: :lower)
      padding = rem(64 - rem(byte_size(hex), 64), 64)

      "0x" <>
        String.pad_leading("20", 64, "0") <>
        String.pad_leading(Integer.to_string(byte_size(value), 16), 64, "0") <>
        hex <> String.duplicate("0", padding)
    end
  end

  setup do
    previous_rpc_client = Application.get_env(:platform_phx, :ethereum_rpc_client)
    previous_ethereum_rpc = System.get_env("ETHEREUM_RPC_URL")
    previous_base_rpc = System.get_env("BASE_RPC_URL")
    previous_registrar = System.get_env("REGENT_ENS_REGISTRAR_ADDRESS")
    previous_owner = System.get_env("REGENT_ENS_OWNER_ADDRESS")
    previous_registry = System.get_env("BASE_IDENTITY_REGISTRY_ADDRESS")

    Application.put_env(:platform_phx, :ethereum_rpc_client, TestEthereumRpcClient)
    System.put_env("ETHEREUM_RPC_URL", "https://ethereum.example.invalid")
    System.put_env("BASE_RPC_URL", "https://base.example.invalid")
    System.put_env("REGENT_ENS_REGISTRAR_ADDRESS", @registrar)
    System.put_env("REGENT_ENS_OWNER_ADDRESS", @owner)
    System.put_env("BASE_IDENTITY_REGISTRY_ADDRESS", @registry)

    on_exit(fn ->
      restore_app_env(:platform_phx, :ethereum_rpc_client, previous_rpc_client)
      restore_system_env("ETHEREUM_RPC_URL", previous_ethereum_rpc)
      restore_system_env("BASE_RPC_URL", previous_base_rpc)
      restore_system_env("REGENT_ENS_REGISTRAR_ADDRESS", previous_registrar)
      restore_system_env("REGENT_ENS_OWNER_ADDRESS", previous_owner)
      restore_system_env("BASE_IDENTITY_REGISTRY_ADDRESS", previous_registry)
    end)

    :ok
  end

  test "prepare_upgrade marks the claim pending and returns a mainnet registrar request" do
    human = insert_human!()
    claim = insert_claim!(human, "tempo")

    assert {:ok, response} = Ens.prepare_upgrade(human, claim.id)
    assert response.claim.claim_status == "upgrade_pending"
    assert response.prepared.chain_id == 1
    assert response.prepared.expected_name == "tempo.regent.eth"
    assert response.prepared.tx_request.to == String.downcase(@registrar)
  end

  test "confirm_upgrade marks the claim onchain after a successful mainnet receipt" do
    human = insert_human!()
    claim = insert_claim!(human, "tempo", %{claim_status: "upgrade_pending"})
    tx_hash = "0x" <> String.duplicate("a", 64)

    TestEthereumRpcClient.put_result("eth_getTransactionReceipt", [tx_hash], %{"status" => "0x1"})

    assert {:ok, response} = Ens.confirm_upgrade(human, claim.id, %{"tx_hash" => tx_hash})
    assert response.claim.claim_status == "onchain_live"
    assert response.claim.upgrade_tx_hash == tx_hash
  end

  test "attach and detach update the mutable ENS assignment without touching formation provenance" do
    human = insert_human!()
    claim = insert_claim!(human, "tempoattach", %{claim_status: "onchain_live"})
    agent = insert_agent!(human, "tempoattach")

    assert {:ok, attached} = Ens.attach(human, agent.slug, %{"claim_id" => claim.id})
    assert get_in(attached, [:agent, :ens, :name]) == "tempoattach.regent.eth"

    reloaded_claim = Repo.get!(Mint, claim.id)
    assert reloaded_claim.attached_agent_slug == agent.slug
    assert reloaded_claim.formation_agent_slug == nil

    assert {:ok, detached} = Ens.detach(human, agent.slug)
    assert get_in(detached, [:agent, :ens, :attached]) == false

    detached_claim = Repo.get!(Mint, claim.id)
    assert detached_claim.attached_agent_slug == nil
    assert detached_claim.formation_agent_slug == nil
  end

  test "prepare_bidirectional returns mainnet ENSIP-25 and reverse actions plus the Base ERC-8004 update" do
    human = insert_human!()

    claim =
      insert_claim!(human, "tempolink", %{
        claim_status: "onchain_live",
        attached_agent_slug: "tempolink"
      })

    _agent = insert_agent!(human, "tempolink", %{ens_fqdn: claim.ens_fqdn})

    assert {:ok, response} =
             Ens.prepare_bidirectional(human, "tempolink", %{
               "agent_id" => 167,
               "registry_address" => @registry,
               "signer_address" => @signer,
               "include_reverse" => true,
               "rpc_module" => RpcReady
             })

    assert response.prepared.plan.ens_name == "tempolink.regent.eth"
    assert response.prepared.ensip25.chain_id == 1
    assert response.prepared.erc8004.chain_id == 8453
    assert response.prepared.reverse.chain_id == 1
    assert response.prepared.plan.ensip25_key =~ "agent-registration[0x0001000002210514"
  end

  test "prepare_primary returns a mainnet reverse-name request for the caller wallet" do
    assert {:ok, response} =
             Ens.prepare_primary(%{"wallet_address" => @wallet}, %{
               "ens_name" => "tempo.regent.eth"
             })

    assert response.prepared.chain_id == 1
    assert response.prepared.ens_name == "tempo.regent.eth"
    assert response.prepared.tx_request.to =~ "0xa58e81"
  end

  defp insert_human! do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "did:privy:test-#{System.unique_integer([:positive])}",
      wallet_address: @wallet,
      wallet_addresses: [@wallet]
    })
    |> Repo.insert!()
  end

  defp insert_claim!(human, label, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Mint{}
    |> Mint.changeset(%{
      parent_node: "0x" <> String.duplicate("1", 64),
      parent_name: "agent.base.eth",
      label: label,
      fqdn: "#{label}.agent.base.eth",
      node:
        "0x" <>
          String.pad_leading(Integer.to_string(System.unique_integer([:positive]), 16), 64, "0"),
      ens_fqdn: "#{label}.regent.eth",
      ens_node:
        "0x" <>
          String.pad_leading(Integer.to_string(System.unique_integer([:positive]), 16), 64, "0"),
      owner_address: human.wallet_address,
      tx_hash: "0x" <> String.duplicate("2", 64),
      payment_tx_hash:
        "0x" <>
          String.pad_leading(Integer.to_string(System.unique_integer([:positive]), 16), 64, "0"),
      payment_chain_id: 8453,
      price_wei: 1,
      is_free: false,
      claim_status: Map.get(attrs, :claim_status, "reserved"),
      formation_agent_slug: Map.get(attrs, :formation_agent_slug),
      attached_agent_slug: Map.get(attrs, :attached_agent_slug),
      created_at: now
    })
    |> Repo.insert!()
  end

  defp insert_agent!(human, slug, attrs \\ %{}) do
    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      template_key: "start",
      name: "#{String.capitalize(slug)} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: Map.get(attrs, :ens_fqdn),
      status: Map.get(attrs, :status, "published"),
      public_summary: "Demo company",
      runtime_status: "ready",
      checkpoint_status: "ready",
      desired_runtime_state: "active",
      observed_runtime_state: "active",
      sprite_metering_status: "trialing"
    })
    |> Repo.insert!()
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)
end
