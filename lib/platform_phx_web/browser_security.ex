defmodule PlatformPhxWeb.BrowserSecurity do
  @moduledoc false

  import Phoenix.Controller, only: [put_secure_browser_headers: 2]
  import Plug.Conn

  alias PlatformPhx.RuntimeConfig

  @behaviour Plug

  @privy_child_src [
    "https://auth.privy.io",
    "https://verify.walletconnect.com",
    "https://verify.walletconnect.org"
  ]

  @privy_frame_src [
    "https://auth.privy.io",
    "https://verify.walletconnect.com",
    "https://verify.walletconnect.org",
    "https://oauth.telegram.org",
    "https://challenges.cloudflare.com"
  ]

  @privy_connect_src [
    "https://auth.privy.io",
    "wss://relay.walletconnect.com",
    "wss://relay.walletconnect.org",
    "wss://www.walletlink.org",
    "https://*.rpc.privy.systems",
    "https://explorer-api.walletconnect.com"
  ]

  @script_src [
    "'self'",
    "https://auth.privy.io",
    "https://telegram.org",
    "https://oauth.telegram.org",
    "https://challenges.cloudflare.com"
  ]

  @style_src [
    "'self'",
    "'unsafe-inline'"
  ]

  @img_src [
    "'self'",
    "data:",
    "blob:",
    "https://pbs.twimg.com",
    "https://explorer-api.walletconnect.com"
  ]

  @font_src ["'self'"]
  @worker_src ["'self'"]
  @manifest_src ["'self'"]
  @default_src ["'self'"]

  @default_frame_ancestors ["'none'"]
  @runtime_env Application.compile_env(:platform_phx, __MODULE__, [])
               |> Keyword.get(:env, :prod)

  def init(opts), do: opts

  def call(conn, _opts) do
    put_headers(conn)
  end

  def put_headers(conn, opts \\ []) do
    nonce = conn.assigns[:csp_nonce] || csp_nonce()
    frame_ancestors = Keyword.get(opts, :frame_ancestors, @default_frame_ancestors)
    runtime_env = Keyword.get(opts, :env, runtime_env())

    conn
    |> assign(:csp_nonce, nonce)
    |> put_secure_browser_headers(%{
      "content-security-policy" =>
        content_security_policy(conn, nonce, frame_ancestors, runtime_env)
    })
  end

  def content_security_policy(
        conn,
        nonce,
        frame_ancestors \\ @default_frame_ancestors,
        runtime_env \\ runtime_env()
      ) do
    connect_src =
      ["'self'", websocket_origin(conn, "ws"), websocket_origin(conn, "wss")]
      |> Kernel.++(@privy_connect_src)
      |> Kernel.++(configured_connect_src())
      |> Enum.uniq()

    [
      directive("default-src", @default_src),
      directive("script-src", ["'nonce-#{nonce}'" | @script_src]),
      directive("style-src", @style_src),
      directive("img-src", @img_src),
      directive("font-src", @font_src),
      directive("object-src", ["'none'"]),
      directive("base-uri", ["'self'"]),
      directive("form-action", ["'self'"]),
      directive("frame-ancestors", frame_ancestors),
      directive("child-src", @privy_child_src),
      directive("frame-src", frame_src(conn, runtime_env)),
      directive("connect-src", connect_src),
      directive("worker-src", @worker_src),
      directive("manifest-src", @manifest_src)
    ]
    |> Enum.join(" ")
  end

  defp directive(name, values) do
    "#{name} #{Enum.join(values, " ")};"
  end

  defp frame_src(conn, :dev) do
    [current_origin(conn) | @privy_frame_src]
    |> Enum.uniq()
  end

  defp frame_src(_conn, _runtime_env), do: @privy_frame_src

  defp current_origin(conn) do
    default_port =
      case conn.scheme do
        :https -> 443
        _ -> 80
      end

    port =
      if conn.port == default_port do
        ""
      else
        ":#{conn.port}"
      end

    "#{conn.scheme}://#{conn.host}#{port}"
  end

  defp websocket_origin(conn, scheme) do
    request_scheme = Atom.to_string(conn.scheme)

    current_port =
      case {request_scheme, scheme} do
        {"http", "ws"} -> conn.port
        {"https", "wss"} -> conn.port
        {"http", "wss"} -> 443
        {"https", "ws"} -> 80
      end

    port =
      case {scheme, current_port} do
        {"ws", 80} -> ""
        {"wss", 443} -> ""
        {_scheme, port} when is_integer(port) -> ":#{port}"
      end

    "#{scheme}://#{conn.host}#{port}"
  end

  defp configured_connect_src do
    [RuntimeConfig.base_rpc_url(), RuntimeConfig.ethereum_rpc_url()]
    |> Enum.map(&origin_from_url/1)
    |> Enum.reject(&is_nil/1)
  end

  defp origin_from_url(nil), do: nil

  defp origin_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, port: port}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        default_port =
          case scheme do
            "https" -> 443
            _ -> 80
          end

        suffix =
          if is_nil(port) or port == default_port do
            ""
          else
            ":#{port}"
          end

        "#{scheme}://#{host}#{suffix}"

      _ ->
        nil
    end
  end

  defp csp_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end

  defp runtime_env do
    @runtime_env
  end
end
