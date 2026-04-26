defmodule PlatformPhxWeb.Api.RegentStakingController do
  use PlatformPhxWeb, :controller
  require Logger

  alias PlatformPhx.RegentStaking
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhx.PublicErrors

  def show(conn, _params) do
    render_result(conn, context_module().overview(current_principal(conn)))
  end

  def account(conn, %{"address" => address}) do
    render_result(conn, context_module().account(address, current_principal(conn)))
  end

  def stake(conn, params) do
    render_result(conn, context_module().stake(params, current_principal(conn)))
  end

  def unstake(conn, params) do
    render_result(conn, context_module().unstake(params, current_principal(conn)))
  end

  def claim_usdc(conn, params) do
    render_result(conn, context_module().claim_usdc(params, current_principal(conn)))
  end

  def claim_regent(conn, params) do
    render_result(conn, context_module().claim_regent(params, current_principal(conn)))
  end

  def claim_and_restake_regent(conn, params) do
    render_result(
      conn,
      context_module().claim_and_restake_regent(params, current_principal(conn))
    )
  end

  defp current_principal(conn) do
    conn.assigns[:current_agent_claims] || %{}
  end

  defp render_result(conn, {:ok, payload}), do: json(conn, Map.put(payload, :ok, true))

  defp render_result(conn, {:error, :unauthorized}),
    do: ApiErrors.error(conn, {:unauthorized, "Sign in before using staking"})

  defp render_result(conn, {:error, :unconfigured}),
    do: ApiErrors.error(conn, {:unavailable, "Regent staking is unavailable right now"})

  defp render_result(conn, {:error, :unavailable}),
    do: ApiErrors.error(conn, {:unavailable, "Regent staking is unavailable right now"})

  defp render_result(conn, {:error, :invalid_address}),
    do: ApiErrors.error(conn, {:bad_request, "Wallet address is invalid"})

  defp render_result(conn, {:error, :amount_required}),
    do: ApiErrors.error(conn, {:bad_request, "Enter an amount before continuing"})

  defp render_result(conn, {:error, :invalid_amount_precision}),
    do: ApiErrors.error(conn, {:bad_request, "Amount uses too many decimals"})

  defp render_result(conn, {:error, reason}) do
    Logger.warning("regent staking request failed #{inspect(%{reason: reason})}")
    ApiErrors.error(conn, {:bad_request, PublicErrors.staking_action()})
  end

  defp context_module do
    Application.get_env(:platform_phx, :regent_staking_api, [])
    |> Keyword.get(:context_module, RegentStaking)
  end
end
