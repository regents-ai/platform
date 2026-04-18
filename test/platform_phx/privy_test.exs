defmodule PlatformPhx.PrivyTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Privy

  test "describe_verify_error explains the common verification failures" do
    assert Privy.describe_verify_error(:missing_privy_config) ==
             "Privy settings are missing from this environment."

    assert Privy.describe_verify_error(:invalid_verification_key) ==
             "The Privy verification key could not be used."

    assert Privy.describe_verify_error(:token_verification_failed) ==
             "The Privy identity token could not be verified."

    assert Privy.describe_verify_error(:invalid_audience) ==
             "The Privy identity token was issued for a different Privy app."

    assert Privy.describe_verify_error(:token_expired) ==
             "The Privy identity token has expired."

    assert Privy.describe_verify_error(:invalid_linked_accounts) ==
             "The Privy identity token linked wallet data was invalid."
  end

  test "describe_verify_error falls back cleanly for unknown failures" do
    assert Privy.describe_verify_error(:something_else) ==
             "Unexpected Privy verification failure: :something_else"
  end
end
