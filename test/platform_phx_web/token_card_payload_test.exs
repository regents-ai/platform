defmodule PlatformPhxWeb.TokenCardPayloadTest do
  use ExUnit.Case, async: true

  alias PlatformPhxWeb.TokenCardPayload

  test "encodes entries as base64url without leaking raw script fragments" do
    marker = ~s|</script><script>alert("xss")</script>|

    payload =
      TokenCardPayload.encode(%{
        "name" => marker,
        "tokenId" => 1,
        "shaderId" => "danger-test"
      })

    refute payload =~ "</script>"
    refute payload =~ "<script>"

    assert payload
           |> Base.url_decode64!(padding: false)
           |> Jason.decode!() == %{
             "name" => marker,
             "shaderId" => "danger-test",
             "tokenId" => 1
           }
  end
end
