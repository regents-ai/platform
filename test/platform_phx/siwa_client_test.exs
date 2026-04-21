defmodule PlatformPhx.SiwaClientTest do
  use ExUnit.Case, async: false

  defmodule StubSiwaServer do
    use Plug.Router

    plug(Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    post "/v1/agent/siwa/http-verify" do
      audience = Plug.Conn.get_req_header(conn, "x-siwa-audience") |> List.first()

      if pid = Application.get_env(:platform_phx, :siwa_test_pid) do
        send(pid, {:siwa_request, audience, conn.body_params})
      end

      case audience do
        "platform" ->
          body = %{
            "ok" => true,
            "code" => "http_envelope_valid",
            "data" => %{
              "verified" => true,
              "walletAddress" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
              "chainId" => 84_532,
              "keyId" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
              "agent_claims" => %{
                "wallet_address" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
                "chain_id" => 84_532,
                "registry_address" => "0x3333333333333333333333333333333333333333",
                "token_id" => "77"
              },
              "receiptExpiresAt" => "2026-04-21T12:00:00Z",
              "requiredHeaders" => [],
              "requiredCoveredComponents" => [],
              "coveredComponents" => []
            }
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(body))

        _ ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            401,
            Jason.encode!(%{
              "ok" => false,
              "error" => %{
                "code" => "receipt_binding_mismatch",
                "message" => "receipt audience does not match this app"
              }
            })
          )
      end
    end
  end

  setup do
    port = 50_000 + rem(System.unique_integer([:positive]), 10_000)

    pid =
      start_supervised!({
        Bandit,
        plug: StubSiwaServer, scheme: :http, ip: {127, 0, 0, 1}, port: port
      })

    previous = System.get_env("SIWA_SERVER_BASE_URL")
    previous_test_pid = Application.get_env(:platform_phx, :siwa_test_pid)
    System.put_env("SIWA_SERVER_BASE_URL", "http://127.0.0.1:#{port}")
    Application.put_env(:platform_phx, :siwa_test_pid, self())

    on_exit(fn ->
      if previous,
        do: System.put_env("SIWA_SERVER_BASE_URL", previous),
        else: System.delete_env("SIWA_SERVER_BASE_URL")

      if previous_test_pid do
        Application.put_env(:platform_phx, :siwa_test_pid, previous_test_pid)
      else
        Application.delete_env(:platform_phx, :siwa_test_pid)
      end

      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  test "http client posts the signed envelope to siwa-server and returns the verified claims" do
    payload = %{
      "method" => "POST",
      "path" => "/api/auth/agent/session",
      "headers" => %{"x-siwa-receipt" => "platform-receipt"},
      "body" => "{}"
    }

    assert {:ok, %{"data" => %{"agent_claims" => claims}}} =
             PlatformPhx.SiwaClient.Http.verify_http_request(payload, audience: "platform")

    assert_receive {:siwa_request, "platform", ^payload}
    assert claims["token_id"] == "77"
  end

  test "http client returns a structured error when siwa-server rejects the request" do
    payload = %{
      "method" => "POST",
      "path" => "/api/auth/agent/session",
      "headers" => %{"x-siwa-receipt" => "techtree-receipt"},
      "body" => "{}"
    }

    assert {:error, {401, "receipt_binding_mismatch", message}} =
             PlatformPhx.SiwaClient.Http.verify_http_request(payload, audience: "techtree")

    assert message =~ "audience"
  end
end
