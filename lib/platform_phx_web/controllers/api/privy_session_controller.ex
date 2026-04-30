defmodule PlatformPhxWeb.Api.PrivySessionController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController
  require Logger

  alias PlatformPhx.Accounts
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.Privy
  alias PlatformPhx.XmtpIdentity
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
         {:ok, xmtp_result} <- xmtp_identity_module().ensure_identity(human),
         {:ok, payload} <- current_human_payload(human, xmtp_result) do
      Logger.info(
        "privy session create succeeded #{inspect(%{privy_user_id: human.privy_user_id, wallet_address: redact_wallet(human.wallet_address), wallet_count: length(List.wrap(human.wallet_addresses)), display_name_present: present?(human.display_name)})}"
      )

      conn
      |> put_session(:current_human_id, human.id)
      |> json(payload)
    else
      {:error, {:bad_request, _message} = reason} ->
        ApiErrors.error(conn, reason)

      {:error, %Ecto.Changeset{} = changeset} ->
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
    |> current_human_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def update_avatar(conn, params) when is_map(params) do
    with %{} = human <- current_human(conn),
         {:ok, attrs} <- avatar_attrs(params),
         {:ok, updated_human} <- AgentPlatform.save_human_avatar(human, attrs),
         {:ok, payload} <- current_human_payload(updated_human) do
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

  def complete_xmtp(conn, params) when is_map(params) do
    with %{} = human <- current_human(conn),
         {:ok, wallet_address} <- current_wallet_address(human),
         {:ok, updated_human} <-
           xmtp_identity_module().complete_identity(human, wallet_address, params),
         {:ok, payload} <- current_human_payload(updated_human, {:ready, updated_human}) do
      json(conn, payload)
    else
      nil ->
        ApiErrors.render(
          conn,
          :unauthorized,
          "privy_session_required",
          "Connect your wallet before you finish room setup."
        )

      {:error, {:missing, key}} ->
        ApiErrors.render(
          conn,
          :unprocessable_entity,
          missing_field_code(key),
          missing_field_message(key)
        )

      {:error, :wallet_address_required} ->
        ApiErrors.render(
          conn,
          :unprocessable_entity,
          "wallet_address_required",
          "Connect your wallet before you continue."
        )

      {:error, :wallet_address_mismatch} ->
        ApiErrors.render(
          conn,
          :unprocessable_entity,
          "wallet_address_mismatch",
          "Finish this step with the same wallet you connected."
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning(
          "privy xmtp completion rejected invalid human payload #{inspect(%{errors: changeset.errors})}"
        )

        ApiErrors.error(conn, {:bad_request, PublicErrors.profile_save()})

      {:error, reason} ->
        Logger.warning("privy xmtp completion failed #{inspect(%{reason: reason})}")

        ApiErrors.render(
          conn,
          :unprocessable_entity,
          "xmtp_setup_failed",
          "We could not finish room setup. Try again."
        )
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

  defp current_wallet_address(%{wallet_address: wallet_address}) when is_binary(wallet_address) do
    case String.trim(wallet_address) do
      "" -> {:error, :wallet_address_required}
      normalized -> {:ok, String.downcase(normalized)}
    end
  end

  defp current_wallet_address(_human), do: {:error, :wallet_address_required}

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

  defp xmtp_identity_module do
    :platform_phx
    |> Application.get_env(:privy_session_controller, [])
    |> Keyword.get(:xmtp_identity_module, XmtpIdentity)
  end

  defp current_human_payload(human, xmtp_result \\ nil)

  defp current_human_payload(nil, _xmtp_result) do
    with {:ok, payload} <- AgentPlatform.current_human_payload(nil) do
      {:ok, Map.put(payload, :xmtp, nil)}
    end
  end

  defp current_human_payload(%HumanUser{} = human, xmtp_result) do
    {resolved_human, xmtp_state} = resolve_session_state(human, xmtp_result)

    with {:ok, payload} <- AgentPlatform.current_human_payload(resolved_human) do
      {:ok,
       payload
       |> Map.put(:xmtp, xmtp_state)
       |> Map.update(:human, nil, fn human_payload ->
         Map.put(human_payload, :xmtp_inbox_id, response_inbox_id(resolved_human, xmtp_state))
       end)}
    end
  end

  defp resolve_session_state(human, nil), do: {human, xmtp_state(human)}

  defp resolve_session_state(_human, {:ready, updated_human}),
    do: {updated_human, ready_xmtp_state(updated_human)}

  defp resolve_session_state(_human, {:signature_required, updated_human, attrs}) do
    {updated_human, signature_required_xmtp_state(updated_human, attrs)}
  end

  defp resolve_session_state(human, _result), do: {human, xmtp_state(human)}

  defp xmtp_state(human) do
    case xmtp_identity_module().ready_inbox_id(human) do
      {:ok, _inbox_id} -> ready_xmtp_state(human)
      {:error, _reason} -> nil
    end
  end

  defp ready_xmtp_state(human) do
    {:ok, inbox_id} = xmtp_identity_module().ready_inbox_id(human)

    %{
      "status" => "ready",
      "inbox_id" => inbox_id,
      "wallet_address" => human.wallet_address
    }
  end

  defp signature_required_xmtp_state(human, attrs) do
    %{
      "status" => "signature_required",
      "inbox_id" => nil,
      "wallet_address" => human.wallet_address,
      "client_id" => Map.get(attrs, "client_id"),
      "signature_request_id" => Map.get(attrs, "signature_request_id"),
      "signature_text" => Map.get(attrs, "signature_text")
    }
  end

  defp response_inbox_id(_human, xmtp_state) do
    case xmtp_state do
      %{"status" => "ready", "inbox_id" => inbox_id} -> inbox_id
      _ -> nil
    end
  end

  defp create_fields do
    [{"display_name", :string, []}]
  end

  defp missing_field_code(key), do: "missing_" <> to_string(key)

  defp missing_field_message(key) do
    case key do
      "wallet_address" -> "Connect a wallet before you continue."
      "client_id" -> "Try connecting again before you finish room setup."
      "signature_request_id" -> "Try connecting again before you finish room setup."
      "signature" -> "Sign the wallet message before you continue."
      _ -> "Finish every required step before you continue."
    end
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
