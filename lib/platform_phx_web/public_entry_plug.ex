defmodule PlatformPhxWeb.PublicEntryPlug do
  @moduledoc false

  import Plug.Conn

  alias PlatformPhxWeb.PublicPageCatalog
  alias PlatformPhxWeb.SiteUrl

  def init(opts), do: opts

  def call(conn, _opts) do
    if public_entry_request?(conn) do
      conn = put_resp_header(conn, "link", Enum.join(link_header(), ", "))

      if markdown_request?(conn) do
        body = PublicPageCatalog.markdown_for_path(conn.request_path) || ""

        conn
        |> put_resp_content_type("text/markdown", "utf-8")
        |> send_resp(200, body)
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp public_entry_request?(%Plug.Conn{method: "GET", request_path: path, host: host}) do
    PublicPageCatalog.public_entry_path?(path) and SiteUrl.public_entry_host?(host)
  end

  defp public_entry_request?(_conn), do: false

  defp markdown_request?(conn) do
    conn
    |> get_req_header("accept")
    |> Enum.any?(&String.contains?(&1, "text/markdown"))
  end

  defp link_header do
    [
      ~s(</.well-known/api-catalog>; rel="api-catalog"),
      ~s(</api-contract.openapiv3.yaml>; rel="service-desc"; type="application/yaml"),
      ~s(<#{SiteUrl.absolute_url("/docs")}>; rel="service-doc")
    ]
  end
end
