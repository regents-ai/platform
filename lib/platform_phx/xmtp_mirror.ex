defmodule PlatformPhx.XMTPMirror do
  @moduledoc false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.XMTPMirror.Messages
  alias PlatformPhx.XMTPMirror.Membership
  alias PlatformPhx.XMTPMirror.Rooms
  alias PlatformPhx.XMTPMirror.XmtpMembershipCommand
  alias PlatformPhx.XMTPMirror.XmtpMessage
  alias PlatformPhx.XMTPMirror.XmtpRoom

  @type room_admin_action_error :: :human_not_found | :room_not_found | :xmtp_identity_required

  @type room_admin_action_status ::
          :enqueued
          | :already_joined
          | :already_pending_join
          | :already_not_joined
          | :already_pending_removal

  @spec ensure_room(map()) :: {:ok, XmtpRoom.t()} | {:error, Ecto.Changeset.t()}
  def ensure_room(attrs) when is_map(attrs), do: Rooms.ensure_room(attrs)

  @spec get_room_by_key(String.t() | nil) :: XmtpRoom.t() | nil
  def get_room_by_key(room_key), do: Rooms.get_room_by_key(room_key)

  @spec room_panel(HumanUser.t() | nil, String.t() | nil) ::
          {:ok, map()} | {:error, :room_not_found}
  def room_panel(current_human, room_key), do: Rooms.room_panel(current_human, room_key)

  @spec ingest_message(map()) ::
          {:ok, XmtpMessage.t()}
          | {:error,
             :room_not_found | :invalid_reply_to_message | :invalid_reactions | Ecto.Changeset.t()}
  def ingest_message(attrs) when is_map(attrs), do: Messages.ingest_message(attrs)

  @spec lease_next_command(String.t() | integer() | nil) :: XmtpMembershipCommand.t() | nil
  def lease_next_command(room_key_or_id), do: Membership.lease_next_command(room_key_or_id)

  @spec resolve_command(integer() | String.t(), map()) ::
          :ok | {:error, :invalid_resolution_status}
  def resolve_command(command_id, attrs), do: Membership.resolve_command(command_id, attrs)

  @spec request_join(HumanUser.t(), map()) ::
          {:ok, map()}
          | {:error, :already_in_room | :room_full | :room_not_found | :xmtp_identity_required}
  def request_join(%HumanUser{} = human, attrs) when is_map(attrs),
    do: Membership.request_join(human, attrs)

  @spec create_human_message(HumanUser.t(), map()) ::
          {:ok, XmtpMessage.t()}
          | {:error,
             :room_not_found
             | :xmtp_identity_required
             | :xmtp_membership_required
             | Ecto.Changeset.t()}
  def create_human_message(%HumanUser{} = human, attrs) when is_map(attrs),
    do: Messages.create_human_message(human, attrs)

  @spec list_public_messages(map()) :: [XmtpMessage.t()]
  def list_public_messages(attrs \\ %{}) when is_map(attrs),
    do: Messages.list_public_messages(attrs)

  @spec heartbeat_presence(HumanUser.t(), map()) ::
          {:ok, map()} | {:error, :room_not_found | :xmtp_identity_required | Ecto.Changeset.t()}
  def heartbeat_presence(%HumanUser{} = human, attrs) when is_map(attrs) do
    Membership.heartbeat_presence(human, attrs)
  end

  @spec add_human_to_room(integer() | String.t(), String.t()) ::
          {:ok, room_admin_action_status()} | {:error, room_admin_action_error()}
  def add_human_to_room(human_id, room_key)
      when (is_integer(human_id) or is_binary(human_id)) and is_binary(room_key) do
    Membership.add_human_to_room(human_id, room_key)
  end

  @spec remove_human_from_room(integer() | String.t(), String.t()) ::
          {:ok, room_admin_action_status()} | {:error, room_admin_action_error()}
  def remove_human_from_room(human_id, room_key)
      when (is_integer(human_id) or is_binary(human_id)) and is_binary(room_key) do
    Membership.remove_human_from_room(human_id, room_key)
  end

  @spec list_shards() :: [map()]
  def list_shards, do: Rooms.list_shards()
end
