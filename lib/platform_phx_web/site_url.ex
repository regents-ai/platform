defmodule PlatformPhxWeb.SiteUrl do
  @moduledoc false

  alias PlatformPhxWeb.Endpoint

  def absolute_url(path) when is_binary(path), do: absolute_url(path, nil)

  def absolute_url(path, host) when is_binary(path) do
    endpoint_uri()
    |> Map.put(:host, host || endpoint_uri().host)
    |> Map.put(:path, path)
    |> Map.put(:query, nil)
    |> Map.put(:fragment, nil)
    |> URI.to_string()
  end

  def absolute_url(%Plug.Conn{} = conn, path) when is_binary(path) do
    %URI{
      scheme: Atom.to_string(conn.scheme),
      host: conn.host,
      port: port_for_uri(conn),
      path: path
    }
    |> URI.to_string()
  end

  def canonicalize_uri(uri) when is_binary(uri) do
    uri
    |> URI.parse()
    |> Map.put(:query, nil)
    |> Map.put(:fragment, nil)
    |> URI.to_string()
  end

  def origin_from_url(url) when is_binary(url) do
    url
    |> URI.parse()
    |> then(fn %{scheme: scheme, host: host, port: port} ->
      suffix =
        case {scheme, port} do
          {"https", 443} -> ""
          {"http", 80} -> ""
          {_scheme, nil} -> ""
          {_scheme, value} -> ":#{value}"
        end

      "#{scheme}://#{host}#{suffix}"
    end)
  end

  def company_host?(host) when is_binary(host) do
    String.ends_with?(host, ".regents.sh") and host not in ["regents.sh", "www.regents.sh"]
  end

  def company_host?(_host), do: false

  def public_entry_host?(host), do: not company_host?(host)

  defp endpoint_uri do
    Endpoint.url()
    |> URI.parse()
    |> normalize_port()
  end

  defp port_for_uri(%Plug.Conn{scheme: :https, port: 443}), do: nil
  defp port_for_uri(%Plug.Conn{scheme: :http, port: 80}), do: nil
  defp port_for_uri(%Plug.Conn{port: port}), do: port

  defp normalize_port(%URI{scheme: "https", port: 443} = uri), do: %{uri | port: nil}
  defp normalize_port(%URI{scheme: "http", port: 80} = uri), do: %{uri | port: nil}
  defp normalize_port(uri), do: uri
end
