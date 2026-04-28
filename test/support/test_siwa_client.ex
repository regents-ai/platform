defmodule PlatformPhx.TestSiwaClient do
  @behaviour PlatformPhx.SiwaClient

  @wallet_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @other_wallet_address "0x0000000000000000000000000000000000000002"
  @chain_id 84_532
  @registry_address "0x3333333333333333333333333333333333333333"
  @token_id "77"
  @other_token_id "78"

  @impl true
  def verify_http_request(%{"headers" => headers}, opts) do
    audience = Keyword.get(opts, :audience)
    receipt = headers["x-siwa-receipt"]

    cond do
      receipt == nil ->
        {:error, {401, "siwa_auth_denied", "Signed agent authentication failed"}}

      receipt == "platform-receipt" and audience == "platform" ->
        {:ok, success_payload()}

      receipt == "platform-receipt-other" and audience == "platform" ->
        {:ok, success_payload(@other_wallet_address, @other_token_id)}

      receipt == "regents-receipt" and audience == "regent-services" ->
        {:ok, success_payload()}

      true ->
        {:error, {401, "receipt_binding_mismatch", "receipt audience does not match this app"}}
    end
  end

  defp success_payload(wallet_address \\ @wallet_address, token_id \\ @token_id) do
    %{
      "ok" => true,
      "code" => "http_envelope_valid",
      "data" => %{
        "verified" => true,
        "walletAddress" => wallet_address,
        "chainId" => @chain_id,
        "keyId" => wallet_address,
        "agent_claims" => %{
          "wallet_address" => wallet_address,
          "chain_id" => @chain_id,
          "registry_address" => @registry_address,
          "token_id" => token_id
        },
        "receiptExpiresAt" => "2026-04-21T12:00:00Z",
        "requiredHeaders" => [],
        "requiredCoveredComponents" => [],
        "coveredComponents" => []
      }
    }
  end
end
