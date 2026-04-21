defmodule PlatformPhxWeb.Api.ReportControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Siwa
  alias PlatformPhx.TestEthereumAdapter
  alias PlatformPhx.OperatorReports.BugReport
  alias PlatformPhx.OperatorReports.SecurityReport
  alias PlatformPhx.Repo

  @wallet_address "0x1111111111111111111111111111111111111111"
  @signed_wallet_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @signed_chain_id 84_532
  @registry_address "0x2222222222222222222222222222222222222222"
  @signed_registry_address "0x3333333333333333333333333333333333333333"
  @signed_token_id "77"

  setup do
    TestEthereumAdapter.put_owner(
      @signed_registry_address,
      @signed_token_id,
      @signed_wallet_address
    )

    on_exit(fn ->
      TestEthereumAdapter.delete_owner(@signed_registry_address, @signed_token_id)
    end)

    :ok
  end

  test "bug endpoint stores and confirms a report", %{conn: conn} do
    response =
      conn
      |> post("/api/bug-report", %{
        "summary" => "  can't do xyz ",
        "details" => " more detail\r\nhere ",
        "reporting_agent" => %{
          "wallet_address" => @wallet_address,
          "chain_id" => 11_155_111,
          "registry_address" => @registry_address,
          "token_id" => "99",
          "label" => "Hermes operator"
        }
      })
      |> json_response(200)

    assert response["ok"] == true
    assert response["public_url"] == "https://regents.sh/bug-report"
    assert response["message"] =~ "status will appear"
    assert response["report"]["summary"] == "can't do xyz"
    assert response["report"]["details"] == "more detail\nhere"
    assert response["report"]["status"] == "pending"
    assert response["report"]["reporting_agent"] == nil

    stored = Repo.get_by!(BugReport, report_id: response["report"]["report_id"])
    assert stored.summary == "can't do xyz"
    assert stored.reporter_wallet_address == nil
  end

  test "bug endpoint ignores forged identity fields on the public route", %{conn: conn} do
    response =
      conn
      |> post("/api/bug-report", %{
        "summary" => "can't do xyz",
        "details" => "details",
        "reporting_agent" => %{
          "wallet_address" => "not-an-address",
          "chain_id" => 11_155_111,
          "registry_address" => @registry_address,
          "token_id" => "99"
        }
      })
      |> json_response(200)

    assert response["report"]["reporting_agent"] == nil
  end

  test "security endpoint stores and confirms a private report", %{conn: conn} do
    response =
      conn
      |> post("/api/security-report", %{
        "summary" => "  private vuln ",
        "details" => " impact and steps ",
        "contact" => " @xyz on telegram ",
        "reporting_agent" => %{
          "wallet_address" => @wallet_address,
          "chain_id" => 11_155_111,
          "registry_address" => @registry_address,
          "token_id" => "99"
        }
      })
      |> json_response(200)

    assert response["ok"] == true
    assert response["message"] =~ "private follow-up"
    assert response["report"]["contact"] == "@xyz on telegram"
    assert response["report"]["reporting_agent"] == nil
    refute Map.has_key?(response, "public_url")

    stored = Repo.get_by!(SecurityReport, report_id: response["report"]["report_id"])
    assert stored.summary == "private vuln"
    assert stored.reporter_wallet_address == nil
  end

  test "security endpoint requires contact", %{conn: conn} do
    response =
      conn
      |> post("/api/security-report", %{
        "summary" => "private vuln",
        "details" => "impact and steps",
        "reporting_agent" => %{
          "wallet_address" => @wallet_address,
          "chain_id" => 11_155_111,
          "registry_address" => @registry_address,
          "token_id" => "99"
        }
      })
      |> json_response(400)

    assert response["statusMessage"] =~ "can't be blank"
  end

  test "signed agent bug route stores the verified agent identity", %{conn: conn} do
    body =
      Jason.encode!(%{"summary" => "signed route", "details" => "keeps verified identity only"})

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/v1/agent/bug-report", body))
      |> post("/v1/agent/bug-report", body)
      |> json_response(200)

    assert response["report"]["reporting_agent"]["wallet_address"] == @signed_wallet_address
    assert response["report"]["reporting_agent"]["chain_id"] == @signed_chain_id
    assert response["report"]["reporting_agent"]["registry_address"] == @signed_registry_address
    assert response["report"]["reporting_agent"]["token_id"] == @signed_token_id
    refute Map.has_key?(response["report"]["reporting_agent"], "label")
  end

  test "signed agent security route stores the verified agent identity", %{conn: conn} do
    body =
      Jason.encode!(%{
        "summary" => "signed security route",
        "details" => "keeps verified identity only",
        "contact" => "ops@regents.sh"
      })

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_headers(agent_headers("/v1/agent/security-report", body))
      |> post("/v1/agent/security-report", body)
      |> json_response(200)

    assert response["report"]["reporting_agent"]["wallet_address"] == @signed_wallet_address
    assert response["report"]["reporting_agent"]["chain_id"] == @signed_chain_id
    assert response["report"]["reporting_agent"]["registry_address"] == @signed_registry_address
    assert response["report"]["reporting_agent"]["token_id"] == @signed_token_id
    refute Map.has_key?(response["report"]["reporting_agent"], "label")
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)
  end

  defp agent_headers(path, body) do
    receipt = verified_receipt()
    created = System.os_time(:second)
    expires = created + 120

    headers = %{
      "x-siwa-receipt" => receipt,
      "x-key-id" => @signed_wallet_address,
      "x-timestamp" => Integer.to_string(created),
      "x-agent-wallet-address" => @signed_wallet_address,
      "x-agent-chain-id" => Integer.to_string(@signed_chain_id),
      "x-agent-registry-address" => @signed_registry_address,
      "x-agent-token-id" => @signed_token_id,
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
      "(#{Enum.map_join(components, " ", &~s("#{&1}"))})" <>
        ";created=#{created}" <>
        ";expires=#{expires}" <>
        ~s(;nonce="req-#{System.unique_integer([:positive])}") <>
        ~s(;keyid="#{@signed_wallet_address}")

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
      TestEthereumAdapter.sign_message(@signed_wallet_address, signing_message)
      |> Base.encode64()

    headers
    |> Map.put("signature-input", "sig1=#{signature_params}")
    |> Map.put("signature", "sig1=:#{signature}:")
  end

  defp verified_receipt do
    assert {:ok, %{"data" => %{"nonce" => nonce}}} =
             Siwa.issue_nonce(%{
               "wallet_address" => @signed_wallet_address,
               "chain_id" => @signed_chain_id,
               "registry_address" => @signed_registry_address,
               "token_id" => @signed_token_id,
               "audience" => "regents.sh"
             })

    message = """
    regent.cx wants you to sign in with your Ethereum account:
    #{@signed_wallet_address}

    URI: https://regent.cx/v1/agent/siwa/verify
    Version: 1
    Chain ID: #{@signed_chain_id}
    Nonce: #{nonce}
    Issued At: 2026-04-16T00:00:00Z
    """

    assert {:ok, %{"data" => %{"receipt" => receipt}}} =
             Siwa.verify_session(%{
               "wallet_address" => @signed_wallet_address,
               "chain_id" => @signed_chain_id,
               "registry_address" => @signed_registry_address,
               "token_id" => @signed_token_id,
               "nonce" => nonce,
               "message" => String.trim(message),
               "signature" =>
                 TestEthereumAdapter.sign_message(@signed_wallet_address, String.trim(message))
             })

    receipt
  end
end
