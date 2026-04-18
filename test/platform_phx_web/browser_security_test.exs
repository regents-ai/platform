defmodule PlatformPhxWeb.BrowserSecurityTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.RuntimeConfig
  alias PlatformPhxWeb.BrowserSecurity

  test "development csp allows the local live reload frame origin" do
    %Plug.Conn{} = conn = Plug.Test.conn(:get, "/")
    conn = %{conn | host: "localhost", port: 4000, scheme: :http}

    csp = BrowserSecurity.content_security_policy(conn, "test-nonce", ["'none'"], :dev)

    assert directive_values(csp, "frame-src") == [
             "http://localhost:4000",
             "https://auth.privy.io",
             "https://verify.walletconnect.com",
             "https://verify.walletconnect.org",
             "https://oauth.telegram.org",
             "https://challenges.cloudflare.com"
           ]
  end

  test "non-development csp omits the local live reload frame origin" do
    %Plug.Conn{} = conn = Plug.Test.conn(:get, "/")
    conn = %{conn | host: "localhost", port: 4000, scheme: :http}

    csp = BrowserSecurity.content_security_policy(conn, "test-nonce", ["'none'"], :test)

    refute csp =~ "http://localhost:4000"
    refute csp =~ "script-src *"
    refute csp =~ "connect-src *"
    refute csp =~ "https:;"

    assert directive_values(csp, "script-src") == [
             "'nonce-test-nonce'",
             "'self'",
             "https://auth.privy.io",
             "https://telegram.org",
             "https://oauth.telegram.org",
             "https://challenges.cloudflare.com"
           ]

    assert directive_values(csp, "frame-src") == [
             "https://auth.privy.io",
             "https://verify.walletconnect.com",
             "https://verify.walletconnect.org",
             "https://oauth.telegram.org",
             "https://challenges.cloudflare.com"
           ]

    assert directive_values(csp, "img-src") == [
             "'self'",
             "data:",
             "blob:",
             "https://pbs.twimg.com",
             "https://explorer-api.walletconnect.com"
           ]

    assert directive_values(csp, "connect-src") == [
             "'self'",
             "ws://localhost:4000",
             "wss://localhost",
             "https://auth.privy.io",
             "wss://relay.walletconnect.com",
             "wss://relay.walletconnect.org",
             "wss://www.walletlink.org",
             "https://*.rpc.privy.systems",
             "https://explorer-api.walletconnect.com",
             connect_origin(RuntimeConfig.base_rpc_url())
           ]
  end

  test "put_headers uses the configured environment without requiring an explicit override" do
    %Plug.Conn{} = conn = Plug.Test.conn(:get, "/")
    conn = %{conn | host: "localhost", port: 4000, scheme: :http}

    conn = BrowserSecurity.put_headers(conn)
    [csp] = Plug.Conn.get_resp_header(conn, "content-security-policy")

    refute csp =~ "http://localhost:4000"
    assert csp =~ "frame-src https://auth.privy.io"
  end

  defp directive_values(csp, directive_name) do
    csp
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.find_value(fn directive ->
      case String.split(directive, " ", parts: 2) do
        [^directive_name, values] -> String.split(values, " ", trim: true)
        _ -> nil
      end
    end)
  end

  defp connect_origin(nil), do: nil

  defp connect_origin(url) do
    uri = URI.parse(url)

    default_port =
      case uri.scheme do
        "https" -> 443
        _ -> 80
      end

    suffix =
      if is_nil(uri.port) or uri.port == default_port do
        ""
      else
        ":#{uri.port}"
      end

    "#{uri.scheme}://#{uri.host}#{suffix}"
  end
end
