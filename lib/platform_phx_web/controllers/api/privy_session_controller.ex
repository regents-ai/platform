defmodule PlatformPhxWeb.Api.PrivySessionController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController
  require Logger

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.Privy
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhxWeb.ApiRequest
  alias PlatformPhx.PublicErrors

  def csrf(conn, _params) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> json(%{ok: true, csrf_token: token})
  end

  def create(conn, params) when is_map(params) do
    log_create_attempt(conn, params)

    with {:ok, attrs} <- ApiRequest.cast(params, create_fields()),
         {:ok, token} <- fetch_bearer_token(conn),
         {:ok, verified_human} <- privy_module().verify_token(token),
         {:ok, human} <- upsert_human(verified_human, attrs),
         {:ok, payload} <- AgentPlatform.current_human_payload(human) do
      Logger.info(
        "privy session create succeeded #{inspect(%{privy_user_id: human.privy_user_id, wallet_address: redact_wallet(human.wallet_address), wallet_count: length(List.wrap(human.wallet_addresses)), display_name_present: present?(human.display_name)})}"
      )

      conn
      |> put_session(:current_human_id, human.id)
      |> json(payload)
    else
      {:error, {:bad_request, _message} = reason} ->
        ApiErrors.error(conn, reason)

      {:error, changeset} when is_map(changeset) ->
        Logger.warning(
          "privy session create rejected invalid human payload #{inspect(%{errors: changeset.errors})}"
        )

        ApiErrors.error(conn, {:bad_request, PublicErrors.profile_save()})

      {:error, :invalid_authorization_header} ->
        Logger.warning(
          "privy session create missing authorization #{inspect(%{authorization_header_present: authorization_header_present?(conn)})}"
        )

        ApiErrors.error(conn, {:unauthorized, "Valid Privy identity token required"})

      {:error, :wallet_required} ->
        Logger.warning(
          "privy session create missing linked wallet #{inspect(%{authorization_header_present: authorization_header_present?(conn), display_name_present: present?(Map.get(params, "display_name"))})}"
        )

        ApiErrors.error(
          conn,
          {:unauthorized, "Valid Privy identity token with a linked wallet required"}
        )

      {:error, reason} ->
        Logger.warning(
          "privy session create failed #{inspect(%{reason: reason, verification_failure: Privy.describe_verify_error(reason), authorization_header_present: authorization_header_present?(conn), display_name_present: present?(Map.get(params, "display_name"))})}"
        )

        ApiErrors.error(conn, {:unauthorized, "Valid Privy identity token required"})
    end
  end

  def show(conn, _params) do
    conn
    |> current_human()
    |> AgentPlatform.current_human_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def update_avatar(conn, params) when is_map(params) do
    with %{} = human <- current_human(conn),
         {:ok, attrs} <- avatar_attrs(params),
         {:ok, updated_human} <- AgentPlatform.save_human_avatar(human, attrs),
         {:ok, payload} <- AgentPlatform.current_human_payload(updated_human) do
      json(conn, payload)
    else
      nil ->
        ApiErrors.error(conn, {:unauthorized, "Sign in before saving an avatar"})

      {:error, {:bad_request, _message} = reason} ->
        ApiErrors.error(conn, reason)

      {:error, reason} ->
        ApiErrors.error(conn, reason)
    end
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

  defp create_fields do
    [{"display_name", :string, []}]
  end

  defp avatar_attrs(params) do
    with {:ok, %{"kind" => kind}} <-
           ApiRequest.cast(params, [
             {"kind", :enum, required: true, values: ["custom_shader", "collection_token"]}
           ]) do
      case kind do
        "custom_shader" ->
          ApiRequest.cast(params, [
            {"kind", :enum, required: true, values: ["custom_shader"]},
            {"shader_id", :string, required: true},
            {"define_values", :map, default: %{}}
          ])

        "collection_token" ->
          collection_avatar_attrs(params)
      end
    end
  end

  defp collection_avatar_attrs(params) do
    ApiRequest.cast(params, [
      {"kind", :enum, required: true, values: ["collection_token"]},
      {"collection", :enum, required: true, values: ["animata1", "animata2", "animataPass"]},
      {"token_id", :integer, required: true}
    ])
  end

  defp log_create_attempt(conn, params) do
    Logger.info(
      "privy session create attempt #{inspect(%{authorization_header_present: authorization_header_present?(conn), display_name_present: present?(Map.get(params, "display_name"))})}"
    )
  end

  defp authorization_header_present?(conn) do
    conn
    |> get_req_header("authorization")
    |> Enum.any?(&(String.trim(&1) != ""))
  end

  defp redact_wallet(wallet_address) when is_binary(wallet_address) do
    trimmed = String.trim(wallet_address)

    if trimmed == "" do
      nil
    else
      "#{String.slice(trimmed, 0, 6)}...#{String.slice(trimmed, -4, 4)}"
    end
  end

  defp redact_wallet(_wallet_address), do: nil

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
