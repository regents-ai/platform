defmodule PlatformPhxWeb.Plugs.RateLimit do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug
  alias PlatformPhxWeb.ApiErrors

  @default_message "Too many requests. Try again shortly."

  def init(opts), do: opts

  def call(conn, opts) do
    rules = Keyword.get(opts, :rules, [])

    case matching_rule(conn, rules) do
      nil ->
        conn

      rule ->
        check(conn, rule)
    end
  end

  defp check(conn, rule) do
    name = Keyword.fetch!(rule, :name)
    limit = Keyword.fetch!(rule, :limit)
    window_ms = Keyword.fetch!(rule, :window_ms)
    key = client_key(conn)

    case PlatformPhx.RateLimiter.check(name, key, limit, window_ms) do
      :ok ->
        conn

      {:error, :limited} ->
        conn
        |> ApiErrors.render_status(:too_many_requests, @default_message)
        |> halt()
    end
  end

  defp matching_rule(conn, rules) do
    Enum.find(rules, fn rule ->
      method = Keyword.fetch!(rule, :method)
      paths = Keyword.get(rule, :paths, [])
      path_prefixes = Keyword.get(rule, :path_prefixes, [])

      conn.method == method and
        (conn.request_path in paths or
           Enum.any?(path_prefixes, &String.starts_with?(conn.request_path, &1)))
    end)
  end

  defp client_key(conn) do
    ip =
      if trusted_proxy_ip?(conn.remote_ip) do
        conn
        |> get_req_header("fly-client-ip")
        |> List.first()
        |> normalize_header_ip()
        |> Kernel.||(forwarded_for_ip(conn))
        |> Kernel.||(format_ip(conn.remote_ip))
      else
        format_ip(conn.remote_ip)
      end

    "#{ip}:#{conn.method}:#{conn.request_path}"
  end

  defp forwarded_for_ip(conn) do
    conn
    |> get_req_header("x-forwarded-for")
    |> List.first()
    |> first_forwarded_ip()
  end

  defp first_forwarded_ip(value) when is_binary(value) do
    value
    |> String.split(",", parts: 2)
    |> List.first()
    |> normalize_header_ip()
  end

  defp first_forwarded_ip(_value), do: nil

  defp normalize_header_ip(nil), do: nil

  defp normalize_header_ip(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      ip -> ip
    end
  end

  defp trusted_proxy_ip?({127, _, _, _}), do: true
  defp trusted_proxy_ip?({10, _, _, _}), do: true
  defp trusted_proxy_ip?({172, second, _, _}) when second in 16..31, do: true
  defp trusted_proxy_ip?({192, 168, _, _}), do: true
  defp trusted_proxy_ip?({169, 254, _, _}), do: true
  defp trusted_proxy_ip?({100, second, _, _}) when second in 64..127, do: true
  defp trusted_proxy_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp trusted_proxy_ip?({first, _, _, _, _, _, _, _}) when first in 0xFC00..0xFDFF, do: true
  defp trusted_proxy_ip?(_ip), do: false

  defp format_ip({a, b, c, d}), do: Enum.join([a, b, c, d], ".")
  defp format_ip(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.join(":")
  defp format_ip(_other), do: "unknown"
end
