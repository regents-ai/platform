defmodule PlatformPhx.WalletActionTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.WalletAction

  test "wallet action builder uses the canonical internal attribute shape" do
    action =
      WalletAction.from_tx(%{
        resource: "regent_staking",
        action: "stake",
        chain_id: 8453,
        to: "0x1111111111111111111111111111111111111111",
        value: "0x0",
        data: "0x1234",
        expected_signer: "0x2222222222222222222222222222222222222222",
        risk_copy: "Review the stake before confirming."
      })

    assert action.resource == "regent_staking"
    assert action.action == "stake"
    assert action.chain_id == 8453
    assert action.to == "0x1111111111111111111111111111111111111111"
    assert action.value == "0x0"
    assert action.data == "0x1234"
    assert action.expected_signer == "0x2222222222222222222222222222222222222222"
    assert action.risk_copy == "Review the stake before confirming."
    assert action.action_id == action.idempotency_key
    assert is_binary(action.expires_at)
  end
end
