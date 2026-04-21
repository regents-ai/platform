defmodule PlatformPhxWeb.DiscoveryController do
  @moduledoc false
  use PlatformPhxWeb, :controller

  alias PlatformPhxWeb.Discovery

  def robots(conn, _params) do
    send_text(conn, "text/plain; charset=utf-8", Discovery.robots_txt())
  end

  def sitemap(conn, _params) do
    send_text(conn, "application/xml; charset=utf-8", Discovery.sitemap_xml())
  end

  def api_catalog(conn, _params) do
    send_json(conn, "application/linkset+json; charset=utf-8", Discovery.api_catalog())
  end

  def agent_card(conn, _params) do
    send_json(conn, "application/json; charset=utf-8", Discovery.agent_card())
  end

  def agent_skills_index(conn, _params) do
    send_json(conn, "application/json; charset=utf-8", Discovery.agent_skills_index())
  end

  def mcp_server_card(conn, _params) do
    send_json(conn, "application/json; charset=utf-8", Discovery.mcp_server_card())
  end

  def healthz(conn, _params) do
    send_text(conn, "text/plain; charset=utf-8", "ok")
  end

  def api_contract(conn, _params) do
    send_text(
      conn,
      "application/yaml; charset=utf-8",
      Discovery.project_file_contents("api-contract.openapiv3.yaml")
    )
  end

  def cli_contract(conn, _params) do
    send_text(
      conn,
      "application/yaml; charset=utf-8",
      Discovery.project_file_contents("cli-contract.yaml")
    )
  end

  def regents_cli_skill(conn, _params) do
    send_text(conn, "text/markdown; charset=utf-8", Discovery.regents_cli_skill())
  end

  defp send_json(conn, content_type, body) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, Jason.encode!(body))
  end

  defp send_text(conn, content_type, body) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end
end
