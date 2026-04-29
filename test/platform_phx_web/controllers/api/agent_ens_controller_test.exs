defmodule PlatformPhxWeb.Api.AgentEnsControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias AgentEns
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.Repo
  alias PlatformPhx.TestEthereumAdapter
  alias PlatformPhx.TestEthereumRpcClient

  @wallet "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @registry "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432"
  @registrar "0x3333333333333333333333333333333333333333"
  @owner "0x4444444444444444444444444444444444444444"
  @signed_chain_id 8453
  @signed_token_id "167"

  defmodule RpcReady do
    @resolver "0x226159d592e2b063810a10ebf6dcbada94ed68b8"
    @signer "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

    def eth_call(_rpc_url, to, data) do
      case {String.downcase(to), data} do
        {"0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e", "0x0178b8bf" <> _node} ->
          {:ok, address_word(@resolver)}

        {"0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e", "0x02571be3" <> _node} ->
          {:ok, address_word(@signer)}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x59d1d43c" <> _rest} ->
          {:ok, encode_string("")}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x01ffc9a7" <> "59d1d43c" <> _padding} ->
          {:ok, bool_word(true)}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x01ffc9a7" <> "3b3b57de" <> _padding} ->
          {:ok, bool_word(true)}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x3b3b57de" <> _rest} ->
          {:ok, address_word(@signer)}

        {"0x226159d592e2b063810a10ebf6dcbada94ed68b8", "0x691f3431" <> _rest} ->
          {:ok, encode_string("")}

        {"0x8004a169fb4a3325136eb29fa0ceb6d2e539a432", "0x6352211e" <> _rest} ->
          {:ok, address_word(@signer)}

        {"0x3333333333333333333333333333333333333333", "0x6352211e" <> _rest} ->
          {:ok, address_word(@signer)}

        {"0x3333333333333333333333333333333333333333", "0x081812fc" <> _rest} ->
          {:ok, address_word("0x0000000000000000000000000000000000000000")}

        {"0x3333333333333333333333333333333333333333", "0xc87b56dd" <> _rest} ->
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

        {"0x3333333333333333333333333333333333333333", "0xe985e9c5" <> _rest} ->
          {:ok, bool_word(false)}

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
    previous_agent_ens_rpc = Application.get_env(:platform_phx, :agent_ens_rpc_module)
    previous_siwa_client = Application.get_env(:platform_phx, :siwa_client)
    previous_ethereum_rpc = System.get_env("ETHEREUM_RPC_URL")
    previous_base_rpc = System.get_env("BASE_RPC_URL")
    previous_registrar = System.get_env("REGENT_ENS_REGISTRAR_ADDRESS")
    previous_owner = System.get_env("REGENT_ENS_OWNER_ADDRESS")
    previous_registry = System.get_env("BASE_IDENTITY_REGISTRY_ADDRESS")

    Application.put_env(:platform_phx, :ethereum_rpc_client, TestEthereumRpcClient)
    Application.put_env(:platform_phx, :agent_ens_rpc_module, RpcReady)
    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)
    System.put_env("ETHEREUM_RPC_URL", "https://ethereum.example.invalid")
    System.put_env("BASE_RPC_URL", "https://base.example.invalid")
    System.put_env("REGENT_ENS_REGISTRAR_ADDRESS", @registrar)
    System.put_env("REGENT_ENS_OWNER_ADDRESS", @owner)
    System.put_env("BASE_IDENTITY_REGISTRY_ADDRESS", @registry)

    on_exit(fn ->
      restore_app_env(:platform_phx, :ethereum_rpc_client, previous_rpc_client)
      restore_app_env(:platform_phx, :agent_ens_rpc_module, previous_agent_ens_rpc)
      restore_app_env(:platform_phx, :siwa_client, previous_siwa_client)
      restore_system_env("ETHEREUM_RPC_URL", previous_ethereum_rpc)
      restore_system_env("BASE_RPC_URL", previous_base_rpc)
      restore_system_env("REGENT_ENS_REGISTRAR_ADDRESS", previous_registrar)
      restore_system_env("REGENT_ENS_OWNER_ADDRESS", previous_owner)
      restore_system_env("BASE_IDENTITY_REGISTRY_ADDRESS", previous_registry)
    end)

    :ok
  end

  test "prepare-upgrade and confirm-upgrade go through the platform routes", %{conn: conn} do
    human = insert_human!()
    claim = insert_claim!(human, "route")
    tx_hash = "0x" <> String.duplicate("a", 64)

    {:ok, upgrade_tx} =
      AgentEns.prepare_regent_subname_upgrade(%{
        chain_id: 1,
        registrar_address: @registrar,
        label: claim.label,
        owner_address: @owner,
        resolver_address: "0x226159d592e2b063810a10ebf6dcbada94ed68b8"
      })

    TestEthereumRpcClient.put_result("eth_getTransactionReceipt", [tx_hash], %{
      "status" => "0x1",
      "blockNumber" => "0x10",
      "logs" => [%{"topics" => [String.downcase(claim.ens_node)]}]
    })

    TestEthereumRpcClient.put_result("eth_getTransactionByHash", [tx_hash], %{
      "to" => @registrar,
      "input" => upgrade_tx.data
    })

    TestEthereumRpcClient.put_result("eth_blockNumber", [], "0x11")

    prepared =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/ens/claims/#{claim.id}/prepare-upgrade", %{})
      |> json_response(200)

    assert prepared["claim"]["claim_status"] == "upgrade_pending"

    confirmed =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/ens/claims/#{claim.id}/confirm-upgrade", %{tx_hash: tx_hash})
      |> json_response(200)

    assert confirmed["claim"]["claim_status"] == "onchain_live"
  end

  test "attach, link-plan, and prepare-bidirectional return the sync details", %{conn: conn} do
    human = insert_human!()
    claim = insert_claim!(human, "routeattach", %{claim_status: "onchain_live"})
    agent = insert_agent!(human, "routeattach", %{wallet_address: @wallet})

    attached =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/agents/#{agent.slug}/ens/attach", %{
        claim_id: claim.id,
        agent_id: 167,
        include_reverse: true
      })
      |> json_response(200)

    assert attached["claim"]["attached_agent_slug"] == agent.slug
    assert attached["prepared"]["forward"] == "noop"
    assert attached["prepared"]["ensip25"]["action"] == "write_ensip25_proof"
    assert attached["prepared"]["erc8004"]["action"] == "update_agent_registration"
    assert attached["prepared"]["reverse"]["action"] == "set_primary_name"

    planned =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/agents/#{agent.slug}/ens/link/plan", %{
        agent_id: 167,
        include_reverse: true
      })
      |> json_response(200)

    assert planned["link"]["forward_resolution_verified"] == true
    assert is_list(planned["link"]["actions"])

    prepared =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/agents/#{agent.slug}/ens/link/prepare-bidirectional", %{
        agent_id: 167,
        include_reverse: true
      })
      |> json_response(200)

    assert prepared["prepared"]["forward"] == "noop"
    assert prepared["prepared"]["ensip25"]["action"] == "write_ensip25_proof"
    assert prepared["prepared"]["erc8004"]["action"] == "update_agent_registration"
    assert prepared["prepared"]["reverse"]["action"] == "set_primary_name"
    assert prepared["prepared"]["cleanup"]["forward"] == "noop"
  end

  test "detach returns cleanup work for stale links", %{conn: conn} do
    human = insert_human!()

    claim =
      insert_claim!(human, "routedetach", %{
        claim_status: "onchain_live",
        attached_agent_slug: "routedetach"
      })

    agent =
      insert_agent!(human, "routedetach", %{
        ens_fqdn: claim.ens_fqdn,
        wallet_address: @wallet
      })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/agents/#{agent.slug}/ens/detach", %{
        agent_id: 167,
        current_agent_uri:
          "data:application/json," <>
            URI.encode_www_form(
              Jason.encode!(%{
                "type" => "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
                "name" => "Demo Agent",
                "services" => [
                  %{"name" => "ENS", "endpoint" => "routedetach.regent.eth", "version" => "v1"}
                ]
              })
            )
      })
      |> json_response(200)

    assert response["cleanup"]["forward"]["action"] == "clear_forward_address"
    assert response["cleanup"]["ensip25"]["action"] == "clear_ensip25_proof"
    assert response["cleanup"]["erc8004"]["chain_id"] == 8453
    assert response["cleanup"]["reverse"]["action"] == "clear_primary_name"
  end

  test "prepare-primary requires the attached name and returns the mainnet reverse transaction",
       %{conn: conn} do
    human = insert_human!()

    claim =
      insert_claim!(human, "routeprimary", %{
        claim_status: "onchain_live",
        attached_agent_slug: "routeprimary"
      })

    _agent =
      insert_agent!(human, "routeprimary", %{
        ens_fqdn: claim.ens_fqdn,
        wallet_address: @wallet
      })

    body = Jason.encode!(%{"ens_name" => claim.ens_fqdn})

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agent-platform/ens/prepare-primary", body))
      |> post("/api/agent-platform/ens/prepare-primary", body)
      |> json_response(200)

    assert response["prepared"]["chain_id"] == 1
    assert response["prepared"]["caller_wallet_address"] == @wallet
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)
  end

  defp agent_headers(path, body) do
    receipt = "regents-receipt"
    created = System.os_time(:second)
    expires = created + 120

    headers = %{
      "x-siwa-receipt" => receipt,
      "x-key-id" => @wallet,
      "x-timestamp" => Integer.to_string(created),
      "x-agent-wallet-address" => @wallet,
      "x-agent-chain-id" => Integer.to_string(@signed_chain_id),
      "x-agent-registry-address" => @registry,
      "x-agent-token-id" => @signed_token_id,
      "content-digest" => content_digest_for_body(body)
    }

    components = [
      "@method",
      "@path",
      "x-siwa-receipt",
      "x-key-id",
      "x-timestamp",
      "x-agent-wallet-address",
      "x-agent-chain-id",
      "x-agent-registry-address",
      "x-agent-token-id",
      "content-digest"
    ]

    signature_params =
      "(#{Enum.map_join(components, " ", &~s("#{&1}"))})" <>
        ";created=#{created}" <>
        ";expires=#{expires}" <>
        ~s(;nonce="req-#{System.unique_integer([:positive])}") <>
        ~s(;keyid="#{@wallet}")

    signing_message =
      components
      |> Enum.map(fn component ->
        value =
          case component do
            "@method" -> "post"
            "@path" -> path
            header_name -> Map.fetch!(headers, header_name)
          end

        ~s("#{component}": #{value})
      end)
      |> Kernel.++([~s("@signature-params": #{signature_params})])
      |> Enum.join("\n")

    signature =
      TestEthereumAdapter.sign_message(@wallet, signing_message)
      |> Base.encode64()

    headers
    |> Map.put("signature-input", "sig1=#{signature_params}")
    |> Map.put("signature", "sig1=:#{signature}:")
  end

  defp content_digest_for_body(body) do
    digest =
      :crypto.hash(:sha256, body)
      |> Base.encode64()

    "sha-256=:#{digest}:"
  end

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
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

  defp insert_agent!(human, slug, attrs) do
    agent_attrs = %{
      owner_human_id: human.id,
      template_key: "start",
      name: "#{String.capitalize(slug)} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: Map.get(attrs, :ens_fqdn),
      wallet_address: Map.get(attrs, :wallet_address),
      status: "published",
      public_summary: "Demo company",
      runtime_status: "ready",
      checkpoint_status: "ready",
      desired_runtime_state: "active",
      observed_runtime_state: "active",
      sprite_metering_status: "trialing"
    }

    company =
      %Company{}
      |> Company.changeset(%{
        owner_human_id: human.id,
        name: agent_attrs.name,
        slug: agent_attrs.slug,
        claimed_label: agent_attrs.claimed_label,
        status: agent_attrs.status,
        public_summary: agent_attrs.public_summary
      })
      |> Repo.insert!()

    %Agent{}
    |> Agent.changeset(Map.put(agent_attrs, :company_id, company.id))
    |> Repo.insert!()
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)
end
