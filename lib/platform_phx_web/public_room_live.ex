defmodule PlatformPhxWeb.PublicRoomLive do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.PublicEvents
  alias PlatformPhx.XMTPMirror
  alias PlatformPhxWeb.CompanyRoomSupport

  def subscribe(socket, _room_key) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = PublicEvents.subscribe()
    end

    :ok
  end

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
    with {:ok, current_human} <- current_human(socket),
         {:ok, _result} <- XMTPMirror.request_join(current_human, %{"room_key" => room_key}),
         {:ok, panel} <- XMTPMirror.room_panel(current_human, room_key) do
      reply_with_panel(socket, panel)
    else
      {:error, reason} -> reply_with_error(socket, reason)
    end
  end

  def handle_join(socket, _room_key), do: {:noreply, socket}

  def handle_send(socket, room_key, body) when is_binary(room_key) do
    with {:ok, normalized_body} <- normalize_message_body(body),
         {:ok, current_human} <- current_human(socket),
         {:ok, _message} <-
           XMTPMirror.create_human_message(current_human, %{
             "room_key" => room_key,
             "body" => normalized_body
           }),
         {:ok, panel} <- XMTPMirror.room_panel(current_human, room_key) do
      reply_with_panel(socket, panel, reset_form?: true)
    else
      {:error, reason} -> reply_with_error(socket, reason, message_body: body)
    end
  end

  def handle_send(socket, _room_key, _body), do: {:noreply, socket}

  def handle_delete_message(socket, room_key, message_id) when is_binary(room_key) do
    _ = {room_key, message_id}
    reply_with_error(socket, :moderator_required)
  end

  def handle_delete_message(socket, _room_key, _message_id), do: {:noreply, socket}

  def handle_kick_user(socket, room_key, target) when is_binary(room_key) do
    _ = {room_key, target}
    reply_with_error(socket, :moderator_required)
  end

  def handle_kick_user(socket, _room_key, _target), do: {:noreply, socket}

  def handle_heartbeat(socket, room_key) when is_binary(room_key) do
    case socket.assigns[:current_human] do
      nil -> :ok
      current_human -> _ = XMTPMirror.heartbeat_presence(current_human, %{"room_key" => room_key})
    end

    {:noreply, socket}
  end

  def handle_heartbeat(socket, _room_key), do: {:noreply, socket}

  defp reply_with_panel(socket, panel, opts \\ []) do
    socket =
      socket
      |> assign_room_panel(panel)
      |> maybe_reset_message_form(Keyword.get(opts, :reset_form?, false))

    {:noreply, socket}
  end

  defp reply_with_error(socket, reason, opts \\ []) do
    socket =
      case Keyword.fetch(opts, :message_body) do
        {:ok, body} -> assign_message_form(socket, body)
        :error -> socket
      end

    {:noreply, put_status(socket, CompanyRoomSupport.reason_message(reason))}
  end

  defp assign_room_panel(socket, panel) do
    assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))
  end

  defp maybe_reset_message_form(socket, true), do: assign_message_form(socket)
  defp maybe_reset_message_form(socket, false), do: socket

  defp current_human(socket) do
    case socket.assigns[:current_human] do
      nil -> {:error, :wallet_required}
      current_human -> {:ok, current_human}
    end
  end

  defp normalize_message_body(body) when is_binary(body) do
    body
    |> String.trim()
    |> case do
      "" -> {:error, :message_required}
      trimmed when byte_size(trimmed) > 10_000 -> {:error, :message_too_long}
      trimmed -> {:ok, trimmed}
    end
  end

  defp normalize_message_body(_body), do: {:error, :message_required}
end
