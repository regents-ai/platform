defmodule PlatformPhxWeb.CompanyRoomSupport do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.XMTPMirror
  alias PlatformPhx.XMTPMirror.Rooms

  def load_room_panel(nil, _human), do: nil

  def load_room_panel(%Agent{} = agent, current_human) do
    load_public_room_panel(Rooms.company_room_key(agent), current_human)
  end

  def load_public_room_panel(room_key, current_human) when is_binary(room_key) do
    case XMTPMirror.room_panel(current_human, room_key) do
      {:ok, panel} -> Map.put(panel, :status_override, nil)
      {:error, _reason} -> nil
    end
  end

  def load_public_room_panel(_room_key, _current_human), do: nil

  def assign_message_form(socket, body \\ "") do
    assign(
      socket,
      :xmtp_message_form,
      Phoenix.Component.to_form(%{"body" => body}, as: :xmtp_room)
    )
  end

  def put_status_override(socket, message) do
    room = socket.assigns[:xmtp_room] || %{}
    assign(socket, :xmtp_room, Map.put(room, :status_override, message))
  end

  def reason_message(:wallet_required),
    do: "Sign in with your wallet before you join this room."

  def reason_message(:room_full),
    do: "All seats are filled right now. You can still read along from this page."

  def reason_message(:already_in_room),
    do: "Leave your current room before joining another one."

  def reason_message(:xmtp_identity_required),
    do: "Reconnect your wallet before you join this room."

  def reason_message(:message_required),
    do: "Write a message before you send it."

  def reason_message(:message_too_long),
    do: "Keep the message shorter so the room stays readable."

  def reason_message(:kicked),
    do: "This wallet was removed from the room."

  def reason_message(:join_required),
    do: "Join the room before you post."

  def reason_message(:moderator_required),
    do: "Only the company owner can do that here."

  def reason_message(:member_not_found),
    do: "That person is no longer in the room."

  def reason_message(:message_not_found),
    do: "That message is no longer available."

  def reason_message(:signature_request_missing),
    do: "That join request expired. Start again when you are ready."

  def reason_message(_reason),
    do: "This room is unavailable right now."
end
