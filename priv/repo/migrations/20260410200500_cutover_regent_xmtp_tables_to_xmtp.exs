defmodule PlatformPhx.Repo.Migrations.CutoverRegentXmtpTablesToXmtp do
  use Ecto.Migration

  def up do
    rename(table(:regent_xmtp_rooms), to: table(:xmtp_rooms))
    rename(table(:regent_xmtp_room_memberships), to: table(:xmtp_room_memberships))
    rename(table(:regent_xmtp_message_logs), to: table(:xmtp_message_logs))

    execute("ALTER INDEX regent_xmtp_rooms_room_key_index RENAME TO xmtp_rooms_room_key_index")

    execute(
      "ALTER INDEX regent_xmtp_rooms_conversation_id_index RENAME TO xmtp_rooms_conversation_id_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_room_memberships_room_id_wallet_address_index RENAME TO xmtp_room_memberships_room_id_wallet_address_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_room_memberships_room_id_inbox_id_index RENAME TO xmtp_room_memberships_room_id_inbox_id_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_room_memberships_membership_state_index RENAME TO xmtp_room_memberships_membership_state_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_message_logs_xmtp_message_id_index RENAME TO xmtp_message_logs_xmtp_message_id_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_message_logs_room_id_sent_at_index RENAME TO xmtp_message_logs_room_id_sent_at_index"
    )

    execute(
      "ALTER INDEX regent_xmtp_message_logs_website_visibility_state_index RENAME TO xmtp_message_logs_website_visibility_state_index"
    )

    execute(
      "ALTER TABLE xmtp_room_memberships RENAME CONSTRAINT regent_xmtp_room_memberships_room_id_fkey TO xmtp_room_memberships_room_id_fkey"
    )

    execute(
      "ALTER TABLE xmtp_message_logs RENAME CONSTRAINT regent_xmtp_message_logs_room_id_fkey TO xmtp_message_logs_room_id_fkey"
    )
  end

  def down do
    execute(
      "ALTER INDEX xmtp_message_logs_website_visibility_state_index RENAME TO regent_xmtp_message_logs_website_visibility_state_index"
    )

    execute(
      "ALTER INDEX xmtp_message_logs_room_id_sent_at_index RENAME TO regent_xmtp_message_logs_room_id_sent_at_index"
    )

    execute(
      "ALTER INDEX xmtp_message_logs_xmtp_message_id_index RENAME TO regent_xmtp_message_logs_xmtp_message_id_index"
    )

    execute(
      "ALTER INDEX xmtp_room_memberships_membership_state_index RENAME TO regent_xmtp_room_memberships_membership_state_index"
    )

    execute(
      "ALTER INDEX xmtp_room_memberships_room_id_inbox_id_index RENAME TO regent_xmtp_room_memberships_room_id_inbox_id_index"
    )

    execute(
      "ALTER INDEX xmtp_room_memberships_room_id_wallet_address_index RENAME TO regent_xmtp_room_memberships_room_id_wallet_address_index"
    )

    execute(
      "ALTER INDEX xmtp_rooms_conversation_id_index RENAME TO regent_xmtp_rooms_conversation_id_index"
    )

    execute("ALTER INDEX xmtp_rooms_room_key_index RENAME TO regent_xmtp_rooms_room_key_index")

    execute(
      "ALTER TABLE xmtp_message_logs RENAME CONSTRAINT xmtp_message_logs_room_id_fkey TO regent_xmtp_message_logs_room_id_fkey"
    )

    execute(
      "ALTER TABLE xmtp_room_memberships RENAME CONSTRAINT xmtp_room_memberships_room_id_fkey TO regent_xmtp_room_memberships_room_id_fkey"
    )

    rename(table(:xmtp_message_logs), to: table(:regent_xmtp_message_logs))
    rename(table(:xmtp_room_memberships), to: table(:regent_xmtp_room_memberships))
    rename(table(:xmtp_rooms), to: table(:regent_xmtp_rooms))
  end
end
