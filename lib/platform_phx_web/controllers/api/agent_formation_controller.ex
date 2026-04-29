defmodule PlatformPhxWeb.Api.AgentFormationController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.ApiRequest
  alias PlatformPhxWeb.ApiErrors

  def formation(conn, _params) do
    conn
    |> current_human()
    |> Formation.formation_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def formation_doctor(conn, _params) do
    conn
    |> current_human()
    |> Formation.doctor_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def projection(conn, _params) do
    conn
    |> current_human()
    |> Formation.projection_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def billing_setup_checkout(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, billing_setup_fields()) do
      conn
      |> current_human()
      |> Formation.start_billing_setup_checkout(attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def create_company(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, create_company_fields()) do
      conn
      |> current_human()
      |> Formation.create_company(attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
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
    with {:ok, attrs} <- ApiRequest.cast(params, billing_topup_fields()) do
      conn
      |> current_human()
      |> Formation.start_billing_topup_checkout(attrs)
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
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

  defp billing_setup_fields do
    [
      {"claimed_name_id", :integer, []},
      {"claimedLabel", :string, []},
      {"success_url", :string, []},
      {"cancel_url", :string, []}
    ]
  end

  defp create_company_fields do
    [
      {"claimed_name_id", :integer, []},
      {"claimedLabel", :string, []}
    ]
  end

  defp billing_topup_fields do
    [{"amountUsdCents", :positive_integer, required: true}]
  end
end
