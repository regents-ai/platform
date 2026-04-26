defmodule PlatformPhxWeb.PublicRoomLive do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.Xmtp
  alias PlatformPhxWeb.CompanyRoomSupport

  def subscribe(socket, room_key) when is_binary(room_key) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = Xmtp.subscribe(room_key)
    end

    :ok
  end

  def subscribe(_socket, _room_key), do: :ok

  def assign_room(socket, room_key) do
    assign(
      socket,
      :xmtp_room,
      CompanyRoomSupport.load_public_room_panel(room_key, socket.assigns[:current_human])
    )
  end

  def assign_message_form(socket, body \\ "") do
    CompanyRoomSupport.assign_message_form(socket, body)
  end

  def put_status(socket, message) do
    CompanyRoomSupport.put_status_override(socket, message)
  end

  def handle_join(socket, room_key) when is_binary(room_key) do
    case Xmtp.request_join(socket.assigns[:current_human], room_key, %{}) do
      {:ok, panel} ->
        {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

      {:needs_signature, %{request_id: request_id, signature_text: signature_text, panel: panel}} ->
        {:noreply,
         socket
         |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
         |> Phoenix.LiveView.push_event("xmtp:sign-request", %{
           request_id: request_id,
           signature_text: signature_text,
           wallet_address: panel.connected_wallet
         })}

      {:error, reason} ->
        {:noreply, put_status(socket, CompanyRoomSupport.reason_message(reason))}
    end
  end

  def handle_join(socket, _room_key), do: {:noreply, socket}

  def handle_join_signature_signed(socket, room_key, request_id, signature)
      when is_binary(room_key) do
    case Xmtp.complete_join_signature(
           socket.assigns[:current_human],
           request_id,
           signature,
           room_key,
           %{}
         ) do
      {:ok, panel} ->
        {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

      {:error, reason} ->
        {:noreply, put_status(socket, CompanyRoomSupport.reason_message(reason))}
    end
  end

  def handle_join_signature_signed(socket, _room_key, _request_id, _signature),
    do: {:noreply, socket}

  def handle_send(socket, room_key, body) when is_binary(room_key) do
    case Xmtp.send_message(socket.assigns[:current_human], body, room_key) do
      {:ok, panel} ->
        {:noreply,
         socket
         |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
         |> assign_message_form()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign_message_form(body)
         |> put_status(CompanyRoomSupport.reason_message(reason))}
    end
  end

  def handle_send(socket, _room_key, _body), do: {:noreply, socket}

  def handle_delete_message(socket, room_key, message_id) when is_binary(room_key) do
    case Xmtp.moderator_delete_message(socket.assigns[:current_human], message_id, room_key) do
      {:ok, panel} ->
        {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

      {:error, reason} ->
        {:noreply, put_status(socket, CompanyRoomSupport.reason_message(reason))}
    end
  end

  def handle_delete_message(socket, _room_key, _message_id), do: {:noreply, socket}

  def handle_kick_user(socket, room_key, target) when is_binary(room_key) do
    case Xmtp.kick_user(socket.assigns[:current_human], target, room_key) do
      {:ok, panel} ->
        {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

      {:error, reason} ->
        {:noreply, put_status(socket, CompanyRoomSupport.reason_message(reason))}
    end
  end

  def handle_kick_user(socket, _room_key, _target), do: {:noreply, socket}

  def handle_heartbeat(socket, room_key) when is_binary(room_key) do
    :ok = Xmtp.heartbeat(socket.assigns[:current_human], room_key)
    {:noreply, socket}
  end

  def handle_heartbeat(socket, _room_key), do: {:noreply, socket}
end
