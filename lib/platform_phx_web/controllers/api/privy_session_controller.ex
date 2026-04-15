defmodule PlatformPhxWeb.Api.PrivySessionController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.Privy
  alias PlatformPhxWeb.ApiErrors

  def csrf(conn, _params) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> json(%{ok: true, csrf_token: token})
  end

  def create(conn, params) when is_map(params) do
    with {:ok, token} <- fetch_bearer_token(conn),
         {:ok, verified_human} <- privy_module().verify_token(token),
         {:ok, human} <- upsert_human(verified_human, params),
         {:ok, payload} <- AgentPlatform.current_human_payload(human) do
      conn
      |> put_session(:current_human_id, human.id)
      |> json(payload)
    else
      {:error, changeset} when is_map(changeset) ->
        ApiErrors.error(conn, {:bad_request, inspect(changeset.errors)})

      {:error, :invalid_authorization_header} ->
        ApiErrors.error(conn, {:unauthorized, "Valid Privy identity token required"})

      {:error, :wallet_required} ->
        ApiErrors.error(
          conn,
          {:unauthorized, "Valid Privy identity token with a linked wallet required"}
        )

      {:error, _reason} ->
        ApiErrors.error(conn, {:unauthorized, "Valid Privy identity token required"})
    end
  end

  def show(conn, _params) do
    conn
    |> current_human()
    |> AgentPlatform.current_human_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json(%{ok: true})
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end

  defp upsert_human(
         %{
           privy_user_id: privy_user_id,
           wallet_address: wallet_address,
           wallet_addresses: wallet_addresses
         },
         params
       )
       when is_map(params) do
    if is_binary(wallet_address) do
      Accounts.upsert_human_by_privy_id(privy_user_id, %{
        "wallet_address" => wallet_address,
        "wallet_addresses" => wallet_addresses,
        "display_name" => Map.get(params, "display_name")
      })
    else
      {:error, :wallet_required}
    end
  end

  defp fetch_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case String.trim(token) do
          "" -> {:error, :invalid_authorization_header}
          normalized -> {:ok, normalized}
        end

      _ ->
        {:error, :invalid_authorization_header}
    end
  end

  defp privy_module do
    :platform_phx
    |> Application.get_env(:privy_session_controller, [])
    |> Keyword.get(:privy_module, Privy)
  end
end
