defmodule PlatformPhx.WalletAction do
  @moduledoc false

  @ttl_seconds 600

  def from_tx(attrs) when is_map(attrs) do
    action = Map.fetch!(attrs, "action")
    chain_id = Map.fetch!(attrs, "chain_id")
    to = Map.fetch!(attrs, "to")
    data = Map.fetch!(attrs, "data")
    expected_signer = Map.get(attrs, "expected_signer")
    resource = Map.fetch!(attrs, "resource")

    %{
      action_id: action_id(resource, action, chain_id, to, data, expected_signer),
      resource: resource,
      action: action,
      chain_id: chain_id,
      to: to,
      value: Map.get(attrs, "value", "0x0"),
      data: data,
      expected_signer: expected_signer,
      expires_at:
        PlatformPhx.Clock.now() |> DateTime.add(@ttl_seconds, :second) |> DateTime.to_iso8601(),
      idempotency_key: action_id(resource, action, chain_id, to, data, expected_signer),
      risk_copy: Map.get(attrs, "risk_copy", "Review this wallet action before confirming.")
    }
  end

  defp action_id(resource, action, chain_id, to, data, expected_signer) do
    :crypto.hash(:sha256, [
      to_string(resource),
      ":",
      to_string(action),
      ":",
      to_string(chain_id),
      ":",
      to_string(to),
      ":",
      to_string(data),
      ":",
      to_string(expected_signer || "")
    ])
    |> Base.encode16(case: :lower)
  end
end
