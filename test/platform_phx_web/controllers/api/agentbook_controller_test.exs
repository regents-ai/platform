defmodule PlatformPhxWeb.Api.AgentbookControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Agentbook.Link
  alias PlatformPhx.Repo
  alias PlatformPhx.TestEthereumAdapter

  @signed_wallet_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @signed_chain_id 84_532
  @signed_registry_address "0x3333333333333333333333333333333333333333"
  @second_wallet_address "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  @second_token_id "78"
  @signed_token_id "77"

  defmodule RegistrationStub do
    def create_session(%{"agent_address" => agent_address, "network" => "world"}) do
      {:ok,
       %{
         session_id: "sess-" <> String.slice(agent_address, -6, 6),
         status: :pending,
         agent_address: String.downcase(agent_address),
         network: "world",
         chain_id: 480,
         contract_address: "0x8b3f4f36c4564ab38c067ca0d7e2ed7d0d16f987",
         relay_url: "https://relay.example.com",
         nonce: 12,
         app_id: "app_test",
         action: "agentbook-registration",
         rp_id: "app_test",
         signal: "0xfeed",
         rp_context: %{
           rp_id: "app_test",
           nonce: "nonce-123",
           created_at: 1_712_000_000,
           expires_at: 1_712_000_300,
           signature: "0xsig"
         },
         expires_at: ~U[2999-01-01 00:00:00Z],
         proof_payload: nil,
         tx_request: nil,
         error_text: nil
       }}
    end

    def submit_proof(session, _proof_payload, _options) do
      {:ok,
       session
       |> Map.put(:status, :registered)
       |> Map.put(:human_id, "0x1234")
       |> Map.put(:error_text, nil)}
    end
  end

  defmodule ManualRegistrationStub do
    def create_session(attrs), do: RegistrationStub.create_session(attrs)

    def submit_proof(session, _proof_payload, _options) do
      {:ok,
       session
       |> Map.put(:status, :proof_ready)
       |> Map.put(:error_text, "manual submission requested")
       |> Map.put(:tx_request, %{
         to: "0x8b3f4f36c4564ab38c067ca0d7e2ed7d0d16f987",
         data: "0x1234"
       })}
    end
  end

  defmodule AgentBookStub do
    def lookup_human(_wallet_address, "world", _options), do: {:ok, "0x1234"}
  end

  setup do
    previous_siwa = Application.get_env(:platform_phx, :siwa_client)
    previous_agentbook = Application.get_env(:platform_phx, :agentbook, [])

    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)

    Application.put_env(
      :platform_phx,
      :agentbook,
      registration_module: RegistrationStub,
      agent_book_module: AgentBookStub
    )

    on_exit(fn ->
      Application.put_env(:platform_phx, :siwa_client, previous_siwa)
      Application.put_env(:platform_phx, :agentbook, previous_agentbook)
    end)

    :ok
  end

  test "signed agent can create and read a hosted trust session", %{conn: conn} do
    body = Jason.encode!(%{"source" => "regents-cli"})

    create_response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agentbook/sessions", body))
      |> post("/api/agentbook/sessions", body)
      |> json_response(200)

    assert create_response["ok"] == true
    assert create_response["session"]["status"] == "pending"
    assert create_response["session"]["wallet_address"] == @signed_wallet_address
    assert create_response["session"]["approval_url"] =~ "/app/trust?session_id=sess-"

    show_response =
      build_conn()
      |> put_req_headers(agent_headers("/api/agentbook/sessions/sess-b92266", ""))
      |> get("/api/agentbook/sessions/sess-b92266")
      |> json_response(200)

    assert show_response["ok"] == true
    assert show_response["session"]["wallet_address"] == @signed_wallet_address

    lookup_response =
      build_conn()
      |> put_req_headers(agent_headers("/api/agentbook/lookup", ""))
      |> get("/api/agentbook/lookup")
      |> json_response(200)

    assert lookup_response["ok"] == true
    assert lookup_response["result"]["connected"] == false
    assert lookup_response["result"]["wallet_address"] == @signed_wallet_address
  end

  test "submitting approval stores trust on the person and the agent", %{conn: conn} do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:trust-human",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Trust Holder"
      })
      |> Repo.insert!()

    create_body = Jason.encode!(%{"source" => "regents-cli"})

    create_response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agentbook/sessions", create_body))
      |> post("/api/agentbook/sessions", create_body)
      |> json_response(200)

    token = approval_token(create_response["session"]["approval_url"])

    submit_response =
      build_conn()
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agentbook/sessions/sess-b92266/submit", %{
        "token" => token,
        "proof" => %{
          "merkle_root" => "0x01",
          "nullifier_hash" => "0x02",
          "proof" => Enum.map(1..8, &"0x#{&1}")
        }
      })
      |> json_response(200)

    assert submit_response["ok"] == true
    assert submit_response["session"]["status"] == "registered"
    assert submit_response["session"]["trust"]["connected"] == true
    assert submit_response["session"]["trust"]["world_human_id"] == "0x1234"
    assert submit_response["session"]["trust"]["unique_agent_count"] == 1

    updated_human = Repo.get!(HumanUser, human.id)
    assert updated_human.world_human_id == "0x1234"
    assert updated_human.world_verified_at

    stored_link = Repo.get_by!(Link, wallet_address: @signed_wallet_address)
    assert stored_link.world_human_id == "0x1234"
    assert stored_link.platform_human_user_id == human.id

    lookup_response =
      build_conn()
      |> put_req_headers(agent_headers("/api/agentbook/lookup", ""))
      |> get("/api/agentbook/lookup")
      |> json_response(200)

    assert lookup_response["result"]["connected"] == true
    assert lookup_response["result"]["world_human_id"] == "0x1234"
    assert lookup_response["result"]["unique_agent_count"] == 1
  end

  test "two different agents linked to the same person raise the unique count", %{conn: conn} do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:shared-trust",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Shared Trust"
      })
      |> Repo.insert!()

    create_payload = Jason.encode!(%{"source" => "regents-cli"})

    create_first =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agentbook/sessions", create_payload))
      |> post("/api/agentbook/sessions", create_payload)
      |> json_response(200)

    complete_session_for_human(
      human.id,
      create_first["session"]["session_id"],
      approval_token(create_first["session"]["approval_url"])
    )

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Link{}
    |> Link.changeset(%{
      wallet_address: @second_wallet_address,
      chain_id: @signed_chain_id,
      registry_address: @signed_registry_address,
      token_id: @second_token_id,
      world_human_id: "0x1234",
      platform_human_user_id: human.id,
      source: "regents-cli",
      first_verified_at: now,
      last_verified_at: now
    })
    |> Repo.insert!()

    second_lookup =
      build_conn()
      |> put_req_headers(second_agent_headers("/api/agentbook/lookup", ""))
      |> get("/api/agentbook/lookup")
      |> json_response(200)

    assert second_lookup["result"]["connected"] == true
    assert second_lookup["result"]["world_human_id"] == "0x1234"
    assert second_lookup["result"]["unique_agent_count"] == 2
  end

  test "a second signed-in person cannot claim the same human-backed trust record", %{conn: conn} do
    first_human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:first-trust",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "First Trust"
      })
      |> Repo.insert!()

    second_human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:second-trust",
        wallet_address: "0x2222222222222222222222222222222222222222",
        wallet_addresses: ["0x2222222222222222222222222222222222222222"],
        display_name: "Second Trust"
      })
      |> Repo.insert!()

    first_create =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agentbook/sessions", Jason.encode!(%{"source" => "regents-cli"})))
      |> post("/api/agentbook/sessions", Jason.encode!(%{"source" => "regents-cli"}))
      |> json_response(200)

    complete_session_for_human(
      first_human.id,
      first_create["session"]["session_id"],
      approval_token(first_create["session"]["approval_url"])
    )

    second_token = "second-token"
    second_token_hash = :crypto.hash(:sha256, second_token) |> Base.encode16(case: :lower)

    Repo.insert_all("platform_agentbook_sessions", [
      %{
        session_id: "sess-second-person",
        wallet_address: @signed_wallet_address,
        chain_id: @signed_chain_id,
        registry_address: @signed_registry_address,
        token_id: @signed_token_id,
        network: "world",
        source: "regents-cli",
        contract_address: "0x8b3f4f36c4564ab38c067ca0d7e2ed7d0d16f987",
        relay_url: "https://relay.example.com",
        nonce: 18,
        approval_token_hash: second_token_hash,
        app_id: "app_test",
        action: "agentbook-registration",
        rp_id: "app_test",
        signal: "0xfeed",
        rp_context: %{
          "rp_id" => "app_test",
          "nonce" => "nonce-456",
          "created_at" => 1_712_000_000,
          "expires_at" => 4_070_908_800,
          "signature" => "0xsig"
        },
        allow_legacy_proofs: false,
        status: "pending",
        expires_at: ~U[2099-01-01 00:00:00Z],
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    conflict_response =
      build_conn()
      |> init_test_session(%{current_human_id: second_human.id})
      |> put_csrf_token()
      |> post("/api/agentbook/sessions/sess-second-person/submit", %{
        "token" => second_token,
        "proof" => %{
          "merkle_root" => "0x01",
          "nullifier_hash" => "0x02",
          "proof" => Enum.map(1..8, &"0x#{&1}")
        }
      })
      |> json_response(409)

    assert conflict_response["statusMessage"] =~ "already attached to another signed-in person"
  end

  test "manual wallet-only follow-up is converted into a failed hosted trust session", %{conn: conn} do
    previous_agentbook = Application.get_env(:platform_phx, :agentbook, [])

    Application.put_env(
      :platform_phx,
      :agentbook,
      registration_module: ManualRegistrationStub,
      agent_book_module: AgentBookStub
    )

    on_exit(fn ->
      Application.put_env(:platform_phx, :agentbook, previous_agentbook)
    end)

    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "did:privy:manual-trust",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "Manual Trust"
      })
      |> Repo.insert!()

    create_response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/agentbook/sessions", Jason.encode!(%{"source" => "regents-cli"})))
      |> post("/api/agentbook/sessions", Jason.encode!(%{"source" => "regents-cli"}))
      |> json_response(200)

    submit_response =
      build_conn()
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agentbook/sessions/#{create_response["session"]["session_id"]}/submit", %{
        "token" => approval_token(create_response["session"]["approval_url"]),
        "proof" => %{
          "merkle_root" => "0x01",
          "nullifier_hash" => "0x02",
          "proof" => Enum.map(1..8, &"0x#{&1}")
        }
      })
      |> json_response(200)

    assert submit_response["session"]["status"] == "failed"
    assert submit_response["session"]["tx_request"] == nil
    assert submit_response["session"]["error_text"] =~ "wallet step"
  end

  defp complete_session_for_human(human_id, session_id, token) do
    build_conn()
    |> init_test_session(%{current_human_id: human_id})
    |> put_csrf_token()
    |> post("/api/agentbook/sessions/#{session_id}/submit", %{
      "token" => token,
      "proof" => %{
        "merkle_root" => "0x01",
        "nullifier_hash" => "0x02",
        "proof" => Enum.map(1..8, &"0x#{&1}")
      }
    })
    |> json_response(200)
  end

  defp approval_token(approval_url) do
    query =
      approval_url
      |> URI.parse()
      |> Map.get(:query, "")
      |> URI.decode_query()

    Map.fetch!(query, "token")
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)
  end

  defp agent_headers(path, body) do
    signed_headers(:post_or_get, path, body, @signed_wallet_address, @signed_token_id)
  end

  defp second_agent_headers(path, body) do
    signed_headers(:post_or_get, path, body, @second_wallet_address, @second_token_id)
  end

  defp signed_headers(_mode, path, body, wallet_address, token_id) do
    receipt = "regents-receipt"
    created = System.os_time(:second)
    expires = created + 120

    headers = %{
      "x-siwa-receipt" => receipt,
      "x-key-id" => wallet_address,
      "x-timestamp" => Integer.to_string(created),
      "x-agent-wallet-address" => wallet_address,
      "x-agent-chain-id" => Integer.to_string(@signed_chain_id),
      "x-agent-registry-address" => @signed_registry_address,
      "x-agent-token-id" => token_id,
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
        ~s(;keyid="#{wallet_address}")

    signing_message =
      components
      |> Enum.map(fn component ->
        value =
          case component do
            "@method" -> if(body == "", do: "get", else: "post")
            "@path" -> path
            header_name -> Map.fetch!(headers, header_name)
          end

        ~s("#{component}": #{value})
      end)
      |> Kernel.++([~s("@signature-params": #{signature_params})])
      |> Enum.join("\n")

    signature =
      TestEthereumAdapter.sign_message(wallet_address, signing_message)
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
end
