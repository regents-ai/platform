defmodule PlatformPhxWeb.PublicCompanyPage do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.AgentPlatform
  alias PlatformPhxWeb.CompanyRoomSupport

  def subscribe(socket, agent) do
    room_agent = room_agent(agent, socket.assigns.current_human)

    if Phoenix.LiveView.connected?(socket) and room_agent do
      :ok = PlatformPhx.Xmtp.subscribe(PlatformPhx.Xmtp.company_room_key(room_agent))
    end

    :ok
  end

  def assign_company_state(socket, agent, assign_key, rendered_agent, page_title) do
    current_human = socket.assigns.current_human
    {owner_company, billing_account} = owner_panel(agent, current_human)
    room_agent = room_agent(agent, current_human)

    socket
    |> assign(:page_title, page_title)
    |> assign(assign_key, rendered_agent)
    |> assign(:owner_company, owner_company)
    |> assign(:billing_account, billing_account)
    |> assign(:xmtp_room, CompanyRoomSupport.load_room_panel(room_agent, current_human))
  end

  def assign_message_form(socket, body \\ "") do
    CompanyRoomSupport.assign_message_form(socket, body)
  end

  def put_xmtp_status(socket, message) do
    CompanyRoomSupport.put_status_override(socket, message)
  end

  def handle_xmtp_join(socket, agent) do
    with room_key when is_binary(room_key) <- room_key(agent, socket.assigns.current_human),
         response <- PlatformPhx.Xmtp.request_join(socket.assigns.current_human, room_key, %{}) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:needs_signature,
         %{request_id: request_id, signature_text: signature_text, panel: panel}} ->
          {:noreply,
           socket
           |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
           |> Phoenix.LiveView.push_event("xmtp:sign-request", %{
             request_id: request_id,
             signature_text: signature_text,
             wallet_address: panel.connected_wallet
           })}

        {:error, reason} ->
          {:noreply, put_xmtp_status(socket, CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_xmtp_join_signature_signed(socket, agent, request_id, signature) do
    with room_key when is_binary(room_key) <- room_key(agent, socket.assigns.current_human),
         response <-
           PlatformPhx.Xmtp.complete_join_signature(
             socket.assigns.current_human,
             request_id,
             signature,
             room_key,
             %{}
           ) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply, put_xmtp_status(socket, CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_xmtp_send(socket, agent, body) do
    with room_key when is_binary(room_key) <- room_key(agent, socket.assigns.current_human),
         response <- PlatformPhx.Xmtp.send_message(socket.assigns.current_human, body, room_key) do
      case response do
        {:ok, panel} ->
          {:noreply,
           socket
           |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
           |> assign_message_form()}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign_message_form(body)
           |> put_xmtp_status(CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_xmtp_delete_message(socket, agent, message_id) do
    with room_key when is_binary(room_key) <- room_key(agent, socket.assigns.current_human),
         response <-
           PlatformPhx.Xmtp.moderator_delete_message(
             socket.assigns.current_human,
             message_id,
             room_key
           ) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply, put_xmtp_status(socket, CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_xmtp_kick_user(socket, agent, target) do
    with room_key when is_binary(room_key) <- room_key(agent, socket.assigns.current_human),
         response <- PlatformPhx.Xmtp.kick_user(socket.assigns.current_human, target, room_key) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply, put_xmtp_status(socket, CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_xmtp_heartbeat(socket, agent) do
    case room_key(agent, socket.assigns.current_human) do
      room_key when is_binary(room_key) ->
        :ok = PlatformPhx.Xmtp.heartbeat(socket.assigns.current_human, room_key)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def runtime_error_message({_, _, message}), do: runtime_error_message(message)
  def runtime_error_message({_, message}), do: runtime_error_message(message)
  def runtime_error_message("Company not found"), do: "Company not found."

  def runtime_error_message("Sign in before pausing a sprite"),
    do: "Sign in before pausing a company."

  def runtime_error_message("Sign in before resuming a sprite"),
    do: "Sign in before resuming a company."

  def runtime_error_message(_reason), do: PlatformPhx.PublicErrors.company_runtime()

  defp owner_panel(%{owner_human_id: owner_human_id, slug: slug}, %{id: human_id} = current_human)
       when owner_human_id == human_id do
    owned_agent = AgentPlatform.get_owned_agent(current_human, slug)
    owner_company = owned_agent && AgentPlatform.serialize_agent(owned_agent, :private)

    billing_account =
      current_human
      |> AgentPlatform.get_billing_account()
      |> AgentPlatform.billing_account_payload(List.wrap(owned_agent))

    {owner_company, billing_account}
  end

  defp owner_panel(_agent, _current_human), do: {nil, nil}

  defp room_key(agent, current_human) do
    case room_agent(agent, current_human) do
      nil -> nil
      room_agent -> PlatformPhx.Xmtp.company_room_key(room_agent)
    end
  end

  defp room_agent(%{slug: slug}, %{} = current_human) when is_binary(slug),
    do: AgentPlatform.get_owned_agent(current_human, slug) || AgentPlatform.get_public_agent(slug)

  defp room_agent(%{slug: slug}, _current_human) when is_binary(slug),
    do: AgentPlatform.get_public_agent(slug)

  defp room_agent(_agent, _current_human), do: nil
end
