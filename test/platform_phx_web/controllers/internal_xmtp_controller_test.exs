defmodule PlatformPhxWeb.InternalXmtpControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Repo
  alias PlatformPhx.XMTPMirror
  alias PlatformPhx.XMTPMirror.XmtpMembershipCommand
  alias PlatformPhx.XMTPMirror.XmtpMessage

  setup %{conn: conn} do
    previous_secret = Application.get_env(:platform_phx, :internal_shared_secret, "")
    Application.put_env(:platform_phx, :internal_shared_secret, "test-internal-secret")

    on_exit(fn ->
      Application.put_env(:platform_phx, :internal_shared_secret, previous_secret)
    end)

    {:ok, conn: put_req_header(conn, "x-platform-secret", "test-internal-secret")}
  end

  test "requires the internal shared secret" do
    conn =
      post(Phoenix.ConnTest.build_conn(), "/api/internal/xmtp/rooms/ensure", %{
        "room_key" => "company:no-secret",
        "xmtp_group_id" => "xmtp-company-no-secret",
        "name" => "Company room"
      })

    assert %{"error" => %{"code" => "internal_auth_required"}} = json_response(conn, 401)
  end

  test "ensures a room and ingests a mirrored message", %{conn: conn} do
    room_key = "company:internal-room-#{System.unique_integer([:positive])}"

    conn =
      post(conn, "/api/internal/xmtp/rooms/ensure", %{
        "room_key" => room_key,
        "xmtp_group_id" => "xmtp-#{room_key}",
        "name" => "Company room"
      })

    assert %{
             "data" => %{
               "room_key" => ^room_key,
               "xmtp_group_id" => "xmtp-" <> _group_id
             }
           } = json_response(conn, 200)

    message_id = "xmtp-message-#{System.unique_integer([:positive])}"

    conn =
      conn
      |> recycle()
      |> put_req_header("x-platform-secret", "test-internal-secret")
      |> post("/api/internal/xmtp/messages/ingest", %{
        "room_key" => room_key,
        "xmtp_message_id" => message_id,
        "sender_inbox_id" => "agent-inbox",
        "sender_label" => "Platform agent",
        "sender_type" => "agent",
        "body" => "Company room update",
        "sent_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    assert %{"data" => %{"id" => id}} = json_response(conn, 200)

    assert %XmtpMessage{id: ^id, body: "Company room update", sender_type: :agent} =
             Repo.get_by!(XmtpMessage, xmtp_message_id: message_id)
  end

  test "leases and resolves membership commands", %{conn: conn} do
    room_key = "formation:company-opening"
    {:ok, room} = ensure_room!(room_key)
    human = insert_human!("0xabc1000000000000000000000000000000000001")

    assert {:ok, _result} = XMTPMirror.request_join(human, %{"room_key" => room.room_key})

    conn =
      post(conn, "/api/internal/xmtp/commands/lease", %{
        "room_key" => room_key
      })

    assert %{"data" => %{"id" => command_id, "op" => "add_member"}} = json_response(conn, 200)

    command = Repo.get!(XmtpMembershipCommand, command_id)
    assert command.status == "processing"
    assert command.attempt_count == 1

    conn =
      conn
      |> recycle()
      |> put_req_header("x-platform-secret", "test-internal-secret")
      |> post("/api/internal/xmtp/commands/#{command_id}/resolve", %{
        "status" => "done"
      })

    assert %{"ok" => true} = json_response(conn, 200)
    assert Repo.get!(XmtpMembershipCommand, command_id).status == "done"
  end

  defp ensure_room!(room_key) do
    XMTPMirror.ensure_room(%{
      "room_key" => room_key,
      "xmtp_group_id" => "xmtp-#{room_key}-#{System.unique_integer([:positive])}",
      "name" => "Platform Room",
      "status" => "active",
      "presence_ttl_seconds" => 120,
      "capacity" => 200
    })
  end

  defp insert_human!(wallet_address) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      xmtp_inbox_id: PlatformPhx.XmtpIdentity.deterministic_inbox_id(wallet_address),
      display_name: "operator@regents.sh"
    })
    |> Repo.insert!()
  end
end
