defmodule PlatformPhxWeb.Api.RegentStakingController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.RegentStaking
  alias PlatformPhxWeb.ApiErrors

  def show(conn, _params) do
    render_result(conn, context_module().overview(current_human(conn)))
  end

  def account(conn, %{"address" => address}) do
    render_result(conn, context_module().account(address, current_human(conn)))
  end

  def stake(conn, params) do
    render_result(conn, context_module().stake(params, current_human(conn)))
  end

  def unstake(conn, params) do
    render_result(conn, context_module().unstake(params, current_human(conn)))
  end

  def claim_usdc(conn, params) do
    render_result(conn, context_module().claim_usdc(params, current_human(conn)))
  end

  def claim_regent(conn, params) do
    render_result(conn, context_module().claim_regent(params, current_human(conn)))
  end

  def claim_and_restake_regent(conn, params) do
    render_result(conn, context_module().claim_and_restake_regent(params, current_human(conn)))
  end

  def prepare_deposit(conn, params) do
    render_result(conn, context_module().prepare_deposit_usdc(params))
  end

  def prepare_withdraw_treasury(conn, params) do
    render_result(conn, context_module().prepare_withdraw_treasury(params))
  end

  defp current_human(conn) do
    if conn.private[:plug_session_fetch] == :done do
      conn
      |> Plug.Conn.get_session(:current_human_id)
      |> PlatformPhx.Accounts.get_human()
    else
      nil
    end
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

  defp render_result(conn, {:error, :source_tag_required}),
    do: ApiErrors.error(conn, {:bad_request, "Source tag is required"})

  defp render_result(conn, {:error, :source_ref_required}),
    do: ApiErrors.error(conn, {:bad_request, "Source reference is required"})

  defp render_result(conn, {:error, :invalid_source_ref}),
    do: ApiErrors.error(conn, {:bad_request, "Source tag or source reference is invalid"})

  defp render_result(conn, {:error, reason}) do
    ApiErrors.error(conn, {:bad_request, inspect(reason)})
  end

  defp context_module do
    Application.get_env(:platform_phx, :regent_staking_api, [])
    |> Keyword.get(:context_module, RegentStaking)
  end
end
