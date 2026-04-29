defmodule PlatformPhxWeb.Api.AgentEnsController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Ens
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhxWeb.ApiRequest

  def prepare_upgrade(conn, %{"claim_id" => claim_id}) do
    conn
    |> current_human()
    |> Ens.prepare_upgrade(claim_id)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def confirm_upgrade(conn, %{"claim_id" => claim_id} = params) do
    with {:ok, attrs} <- ApiRequest.cast(params, confirm_upgrade_fields()) do
      conn
      |> current_human()
      |> Ens.confirm_upgrade(claim_id, attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def attach(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- ApiRequest.cast(params, link_fields()) do
      conn
      |> current_human()
      |> Ens.attach(slug, attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def detach(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- ApiRequest.cast(params, link_fields()) do
      conn
      |> current_human()
      |> Ens.detach(slug, attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def link_plan(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- ApiRequest.cast(params, link_fields()) do
      conn
      |> current_human()
      |> Ens.link_plan(slug, attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def prepare_bidirectional(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- ApiRequest.cast(params, link_fields()) do
      conn
      |> current_human()
      |> Ens.prepare_bidirectional(slug, attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def prepare_primary(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, primary_fields()) do
      conn.assigns[:current_agent_claims]
      |> Ens.prepare_primary(attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end

  defp confirm_upgrade_fields, do: [{"tx_hash", :string, required: true}]

  defp link_fields do
    [
      {"claim_id", :integer, []},
      {"agent_id", :integer, []},
      {"registry_address", :string, []},
      {"current_agent_uri", :string, []},
      {"include_reverse", :boolean, []},
      {"rpc_module", :map, []},
      {"erc8004_fetcher", :map, []}
    ]
  end

  defp primary_fields do
    [
      {"ens_name", :string, required: true},
      {"current_agent_uri", :string, []},
      {"rpc_module", :map, []},
      {"erc8004_fetcher", :map, []}
    ]
  end
end
