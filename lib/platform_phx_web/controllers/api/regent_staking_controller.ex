defmodule PlatformPhxWeb.Api.RegentStakingController do
  use PlatformPhxWeb, :controller
  require Logger

  alias PlatformPhx.RegentStaking
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhx.PublicErrors

  @staking_actions %{
    show: {:overview, :principal},
    account: {:account, :address_and_principal},
    stake: {:stake, :params_and_principal},
    unstake: {:unstake, :params_and_principal},
    claim_usdc: {:claim_usdc, :params_and_principal},
    claim_regent: {:claim_regent, :params_and_principal},
    claim_and_restake_regent: {:claim_and_restake_regent, :params_and_principal}
  }

  @staking_errors %{
    unauthorized: {:unauthorized, "Sign in before using staking"},
    unconfigured: {:unavailable, "Regent staking is unavailable right now"},
    unavailable: {:unavailable, "Regent staking is unavailable right now"},
    invalid_address: {:bad_request, "Wallet address is invalid"},
    amount_required: {:bad_request, "Enter an amount before continuing"},
    invalid_amount_precision: {:bad_request, "Amount uses too many decimals"}
  }

  for action <- Map.keys(@staking_actions) do
    def unquote(action)(conn, params), do: dispatch(conn, unquote(action), params)
  end

  defp current_principal(conn) do
    conn.assigns[:current_agent_claims] || %{}
  end

  defp dispatch(conn, action, params) do
    {function, args_shape} = Map.fetch!(@staking_actions, action)

    context_module()
    |> apply(function, action_args(args_shape, conn, params))
    |> then(&render_result(conn, &1))
  end

  defp action_args(:principal, conn, _params), do: [current_principal(conn)]

  defp action_args(:address_and_principal, conn, %{"address" => address}),
    do: [address, current_principal(conn)]

  defp action_args(:params_and_principal, conn, params), do: [params, current_principal(conn)]

  defp render_result(conn, {:ok, payload}), do: json(conn, Map.put(payload, :ok, true))

  defp render_result(conn, {:error, reason}), do: ApiErrors.error(conn, translate_error(reason))

  defp translate_error(reason) do
    case Map.fetch(@staking_errors, reason) do
      {:ok, error} ->
        error

      :error ->
        Logger.warning("regent staking request failed #{inspect(%{reason: reason})}")
        {:bad_request, PublicErrors.staking_action()}
    end
  end

  defp context_module do
    Application.get_env(:platform_phx, :regent_staking_api, [])
    |> Keyword.get(:context_module, RegentStaking)
  end
end
