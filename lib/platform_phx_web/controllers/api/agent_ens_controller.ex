defmodule PlatformPhxWeb.Api.AgentEnsController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Ens
  alias PlatformPhxWeb.ApiErrors

  def prepare_upgrade(conn, %{"claim_id" => claim_id}) do
    conn
    |> current_human()
    |> Ens.prepare_upgrade(claim_id)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def confirm_upgrade(conn, %{"claim_id" => claim_id} = params) do
    conn
    |> current_human()
    |> Ens.confirm_upgrade(claim_id, params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def attach(conn, %{"slug" => slug} = params) do
    conn
    |> current_human()
    |> Ens.attach(slug, params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def detach(conn, %{"slug" => slug} = params) do
    conn
    |> current_human()
    |> Ens.detach(slug, params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def link_plan(conn, %{"slug" => slug} = params) do
    conn
    |> current_human()
    |> Ens.link_plan(slug, params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def prepare_bidirectional(conn, %{"slug" => slug} = params) do
    conn
    |> current_human()
    |> Ens.prepare_bidirectional(slug, params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def prepare_primary(conn, params) do
    conn.assigns[:current_agent_claims]
    |> Ens.prepare_primary(params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end
end
