defmodule PlatformPhxWeb.CompanyRoomSupport do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.Xmtp

  def load_room_panel(nil, _human), do: nil

  def load_room_panel(%Agent{} = agent, current_human) do
    _ = safe_bootstrap(agent)

    case Xmtp.company_room_panel(current_human, agent, %{}) do
      {:ok, panel} -> Map.put(panel, :status_override, nil)
      {:error, _reason} -> nil
    end
  end

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

  def safe_bootstrap(%Agent{} = agent) do
    case Xmtp.bootstrap_company_room!(agent, reuse: true) do
      {:ok, _room} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _error -> :error
  end
end
