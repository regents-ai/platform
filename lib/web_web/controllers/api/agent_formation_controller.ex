defmodule WebWeb.Api.AgentFormationController do
  use WebWeb, :controller

  alias Web.Accounts
  alias Web.AgentPlatform.Formation
  alias WebWeb.ApiErrors

  def formation(conn, _params) do
    conn
    |> current_human()
    |> Formation.formation_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def llm_billing_checkout(conn, _params) do
    conn
    |> current_human()
    |> Formation.start_llm_billing_checkout()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def create_company(conn, params) do
    conn
    |> current_human()
    |> Formation.create_company(params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def runtime(conn, %{"slug" => slug}) do
    conn
    |> current_human()
    |> Formation.runtime_payload(slug)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def credits(conn, _params) do
    conn
    |> current_human()
    |> Formation.credit_summary()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def checkout_credits(conn, params) do
    conn
    |> current_human()
    |> Formation.start_credit_checkout(params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end
end
