defmodule PlatformPhxWeb.Plugs.RateLimit do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

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
        |> put_status(:too_many_requests)
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{"statusMessage" => @default_message}))
        |> halt()
    end
  end

  defp matching_rule(conn, rules) do
    Enum.find(rules, fn rule ->
      method = Keyword.fetch!(rule, :method)
      paths = Keyword.fetch!(rule, :paths)

      conn.method == method and conn.request_path in paths
    end)
  end

  defp client_key(conn) do
    ip =
      conn
      |> get_req_header("fly-client-ip")
      |> List.first()
      |> normalize_header_ip()
      |> Kernel.||(forwarded_for_ip(conn))
      |> Kernel.||(format_ip(conn.remote_ip))

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

  defp format_ip({a, b, c, d}), do: Enum.join([a, b, c, d], ".")
  defp format_ip(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.join(":")
  defp format_ip(_other), do: "unknown"
end
