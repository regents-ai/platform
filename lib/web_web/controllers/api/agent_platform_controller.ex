defmodule WebWeb.Api.AgentPlatformController do
  use WebWeb, :controller

  alias Web.AgentPlatform
  alias WebWeb.ApiErrors

  def templates(conn, _params) do
    json(conn, %{ok: true, templates: AgentPlatform.list_templates()})
  end

  def resolve(conn, %{"host" => host}) do
    ApiErrors.respond(conn, AgentPlatform.resolve_host_payload(host))
  end

  def resolve(conn, _params) do
    ApiErrors.error(conn, {:bad_request, "Invalid host"})
  end

  def feed(conn, %{"slug" => slug}) do
    ApiErrors.respond(conn, AgentPlatform.feed_payload(slug))
  end
end
