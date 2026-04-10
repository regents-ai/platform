defmodule PlatformPhxWeb.Api.AgentFormationController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.ApiErrors

  def formation(conn, _params) do
    conn
    |> current_human()
    |> Formation.formation_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def billing_setup_checkout(conn, params) do
    conn
    |> current_human()
    |> Formation.start_billing_setup_checkout(params)
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

  def billing_account(conn, _params) do
    conn
    |> current_human()
    |> Formation.billing_account_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def billing_usage(conn, _params) do
    conn
    |> current_human()
    |> Formation.billing_usage()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def billing_topup_checkout(conn, params) do
    conn
    |> current_human()
    |> Formation.start_billing_topup_checkout(params)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def pause_sprite(conn, %{"slug" => slug}) do
    conn
    |> current_human()
    |> Formation.pause_sprite(slug)
    |> then(&ApiErrors.respond(conn, &1))
  end

  def resume_sprite(conn, %{"slug" => slug}) do
    conn
    |> current_human()
    |> Formation.resume_sprite(slug)
    |> then(&ApiErrors.respond(conn, &1))
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end
end
