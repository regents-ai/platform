defmodule PlatformPhxWeb.Api.AgentSessionControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Siwa
  alias PlatformPhx.TestEthereumAdapter

  @wallet_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @chain_id 84_532
  @registry_address "0x3333333333333333333333333333333333333333"
  @token_id "77"

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
          "session_id" => "expired-platform-session",
          "audience" => "platform",
          "wallet_address" => @wallet_address,
          "chain_id" => @chain_id,
          "registry_address" => @registry_address,
          "token_id" => @token_id,
          "issued_at" => "2026-04-17T00:00:00Z",
          "expires_at" => "2026-04-17T00:00:01Z"
        }
      })
      |> get("/api/auth/agent/session")

    assert %{"ok" => true, "session" => nil} = json_response(expired_conn, 200)
  end

  test "shared SIWA login can exchange into a local platform session", %{conn: conn} do
    nonce_conn =
      conn
      |> post("/v1/agent/siwa/nonce", %{
        "wallet_address" => @wallet_address,
        "chain_id" => @chain_id,
        "registry_address" => @registry_address,
        "token_id" => @token_id,
        "audience" => "platform"
      })

    %{"data" => %{"nonce" => nonce}} = json_response(nonce_conn, 200)

    message =
      """
      regent.cx wants you to sign in with your Ethereum account:
      #{@wallet_address}

      URI: https://regent.cx/v1/agent/siwa/verify
      Version: 1
      Chain ID: #{@chain_id}
      Nonce: #{nonce}
      Issued At: 2026-04-16T00:00:00Z
      """
      |> String.trim()

    verify_conn =
      conn
      |> post("/v1/agent/siwa/verify", %{
        "wallet_address" => @wallet_address,
        "chain_id" => @chain_id,
        "registry_address" => @registry_address,
        "token_id" => @token_id,
        "nonce" => nonce,
        "message" => message,
        "signature" => TestEthereumAdapter.sign_message(@wallet_address, message)
      })

    %{"data" => %{"receipt" => receipt}} = json_response(verify_conn, 200)

    body = "{}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    session_conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token(csrf_token)
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/auth/agent/session", body, receipt))
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
    nonce_conn =
      conn
      |> post("/v1/agent/siwa/nonce", %{
        "wallet_address" => @wallet_address,
        "chain_id" => @chain_id,
        "registry_address" => @registry_address,
        "token_id" => @token_id,
        "audience" => "techtree"
      })

    %{"data" => %{"nonce" => nonce}} = json_response(nonce_conn, 200)

    message =
      """
      regent.cx wants you to sign in with your Ethereum account:
      #{@wallet_address}

      URI: https://regent.cx/v1/agent/siwa/verify
      Version: 1
      Chain ID: #{@chain_id}
      Nonce: #{nonce}
      Issued At: 2026-04-16T00:00:00Z
      """
      |> String.trim()

    verify_conn =
      conn
      |> post("/v1/agent/siwa/verify", %{
        "wallet_address" => @wallet_address,
        "chain_id" => @chain_id,
        "registry_address" => @registry_address,
        "token_id" => @token_id,
        "nonce" => nonce,
        "message" => message,
        "signature" => TestEthereumAdapter.sign_message(@wallet_address, message)
      })

    %{"data" => %{"receipt" => receipt}} = json_response(verify_conn, 200)

    body = "{}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    session_conn =
      conn
      |> init_test_session(%{})
      |> put_csrf_token(csrf_token)
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/api/auth/agent/session", body, receipt))
      |> post("/api/auth/agent/session", body)

    assert %{"ok" => false, "error" => %{"code" => "siwa_auth_denied"}} =
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

  defp agent_headers(path, body, receipt \\ nil) do
    receipt = receipt || verified_receipt()
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
      "content-digest" => Siwa.content_digest_for_body(body)
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
      "(#{Enum.map_join(components, " ", &~s(\"#{&1}\"))})" <>
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

        ~s(\"#{component}\": #{value})
      end)
      |> Kernel.++([~s(\"@signature-params\": #{signature_params})])
      |> Enum.join("\n")

    signature =
      TestEthereumAdapter.sign_message(@wallet_address, signing_message)
      |> Base.encode64()

    headers
    |> Map.put("signature-input", "sig1=#{signature_params}")
    |> Map.put("signature", "sig1=:#{signature}:")
  end

  defp verified_receipt do
    assert {:ok, %{"data" => %{"nonce" => nonce}}} =
             Siwa.issue_nonce(%{
               "wallet_address" => @wallet_address,
               "chain_id" => @chain_id,
               "registry_address" => @registry_address,
               "token_id" => @token_id,
               "audience" => "platform"
             })

    message =
      """
      regent.cx wants you to sign in with your Ethereum account:
      #{@wallet_address}

      URI: https://regent.cx/v1/agent/siwa/verify
      Version: 1
      Chain ID: #{@chain_id}
      Nonce: #{nonce}
      Issued At: 2026-04-16T00:00:00Z
      """
      |> String.trim()

    assert {:ok, %{"data" => %{"receipt" => receipt}}} =
             Siwa.verify_session(%{
               "wallet_address" => @wallet_address,
               "chain_id" => @chain_id,
               "registry_address" => @registry_address,
               "token_id" => @token_id,
               "nonce" => nonce,
               "message" => message,
               "signature" => TestEthereumAdapter.sign_message(@wallet_address, message)
             })

    receipt
  end
end
