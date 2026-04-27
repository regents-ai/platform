defmodule PlatformPhxWeb.Api.AgentSessionControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.TestEthereumAdapter

  @wallet_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @chain_id 84_532
  @registry_address "0x3333333333333333333333333333333333333333"
  @token_id "77"

  setup do
    previous_client = Application.get_env(:platform_phx, :siwa_client)
    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)

    on_exit(fn ->
      Application.put_env(:platform_phx, :siwa_client, previous_client)
    end)

    :ok
  end

  test "create, show, and delete keep the full verified agent identity in the local app session",
       %{
         conn: conn
       } do
    body = "{}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    created_conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token(csrf_token)
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/auth/agent/session", body))
      |> post("/api/auth/agent/session", body)

    created = json_response(created_conn, 200)

    assert created["ok"] == true
    assert created["session"]["audience"] == "platform"
    assert created["session"]["wallet_address"] == @wallet_address
    assert created["session"]["chain_id"] == @chain_id
    assert created["session"]["registry_address"] == @registry_address
    assert created["session"]["token_id"] == @token_id
    assert is_binary(created["session"]["session_id"])

    show_conn =
      created_conn
      |> recycle()
      |> get("/api/auth/agent/session")

    shown = json_response(show_conn, 200)

    assert shown["ok"] == true
    assert shown["session"]["session_id"] == created["session"]["session_id"]
    assert shown["session"]["registry_address"] == @registry_address
    assert shown["session"]["token_id"] == @token_id

    delete_conn =
      show_conn
      |> recycle()
      |> put_req_header("x-csrf-token", csrf_token)
      |> delete("/api/auth/agent/session")

    assert %{"ok" => true} = json_response(delete_conn, 200)

    cleared_conn =
      delete_conn
      |> recycle()
      |> get("/api/auth/agent/session")

    assert %{"ok" => true, "session" => nil} = json_response(cleared_conn, 200)
  end

  test "show clears an expired local agent session", %{conn: conn} do
    expired_conn =
      conn
      |> init_test_session(%{
        agent_session: %{
          session_id: "expired-platform-session",
          audience: "platform",
          wallet_address: @wallet_address,
          chain_id: @chain_id,
          registry_address: @registry_address,
          token_id: @token_id,
          issued_at: "2026-04-17T00:00:00Z",
          expires_at: "2026-04-17T00:00:01Z"
        }
      })
      |> get("/api/auth/agent/session")

    assert %{"ok" => true, "session" => nil} = json_response(expired_conn, 200)
  end

  test "show clears a malformed local agent session instead of keeping it", %{conn: conn} do
    malformed_conn =
      conn
      |> init_test_session(%{
        agent_session: %{
          session_id: "broken-platform-session",
          audience: "platform",
          wallet_address: @wallet_address,
          chain_id: @chain_id,
          registry_address: @registry_address,
          token_id: @token_id,
          issued_at: "2026-04-17T00:00:00Z",
          expires_at: "not-a-real-time"
        }
      })
      |> get("/api/auth/agent/session")

    assert %{"ok" => true, "session" => nil} = json_response(malformed_conn, 200)
  end

  test "show clears a local agent session minted for another app", %{conn: conn} do
    wrong_audience_conn =
      conn
      |> init_test_session(%{
        agent_session: %{
          session_id: "wrong-platform-session",
          audience: "techtree",
          wallet_address: @wallet_address,
          chain_id: @chain_id,
          registry_address: @registry_address,
          token_id: @token_id,
          issued_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          expires_at: DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_iso8601()
        }
      })
      |> get("/api/auth/agent/session")

    assert %{"ok" => true, "session" => nil} = json_response(wrong_audience_conn, 200)
  end

  test "shared SIWA login can exchange into a local platform session", %{conn: conn} do
    body = "{}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    session_conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token(csrf_token)
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/auth/agent/session", body, "platform-receipt"))
      |> post("/api/auth/agent/session", body)

    response = json_response(session_conn, 200)

    assert response["ok"] == true
    assert response["session"]["audience"] == "platform"
    assert response["session"]["wallet_address"] == @wallet_address
    assert response["session"]["registry_address"] == @registry_address
    assert response["session"]["token_id"] == @token_id
  end

  test "shared SIWA proof for a different audience cannot create a platform session", %{
    conn: conn
  } do
    body = "{}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    session_conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token(csrf_token)
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/auth/agent/session", body, "techtree-receipt"))
      |> post("/api/auth/agent/session", body)

    assert %{"statusMessage" => "Signed agent authentication failed"} =
             json_response(session_conn, 401)
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)
  end

  defp put_csrf_token(conn, token) do
    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end

  defp agent_headers(path, body, receipt \\ "platform-receipt") do
    created = System.os_time(:second)
    expires = created + 120

    headers = %{
      "x-siwa-receipt" => receipt,
      "x-key-id" => @wallet_address,
      "x-timestamp" => Integer.to_string(created),
      "x-agent-wallet-address" => @wallet_address,
      "x-agent-chain-id" => Integer.to_string(@chain_id),
      "x-agent-registry-address" => @registry_address,
      "x-agent-token-id" => @token_id,
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
        ~s(;keyid="#{@wallet_address}")

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
      TestEthereumAdapter.sign_message(@wallet_address, signing_message)
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
end
