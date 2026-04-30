defmodule PlatformPhx.XMTPMirrorTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.PublicEvents
  alias PlatformPhx.Repo
  alias PlatformPhx.XMTPMirror
  alias PlatformPhx.XMTPMirror.Rooms
  alias PlatformPhx.XMTPMirror.XmtpMembershipCommand
  alias PlatformPhx.XMTPMirror.XmtpPresence
  alias PlatformPhxWeb.CompanyRoomSupport

  test "company rooms keep the company owner as moderator" do
    human = insert_human!("0xabc0000000000000000000000000000000000001")
    agent = insert_agent!(human, "owner-split")
    room_key = Rooms.company_room_key(agent)

    assert {:ok, room} =
             XMTPMirror.ensure_room(%{
               "room_key" => room_key,
               "xmtp_group_id" => "xmtp-#{room_key}",
               "name" => "#{agent.name} Room"
             })

    assert room.room_key == room_key
    assert room.xmtp_group_id == "xmtp-#{room_key}"

    assert {:ok, owner_panel} = XMTPMirror.room_panel(human, room_key)
    assert owner_panel.moderator? == true
    assert owner_panel.connected_wallet == String.downcase(human.wallet_address)
  end

  test "formation room is a 200 seat human room" do
    human = insert_human!("0xabc0000000000000000000000000000000000002")
    room_key = Rooms.formation_room_key()
    ensure_room!(room_key, "Formation Room")

    assert {:ok, panel} = XMTPMirror.room_panel(human, room_key)
    assert panel.room_key == room_key
    assert panel.room_name == "Formation Room"
    assert panel.seat_count == 200
    assert panel.seats_remaining == 200
    assert panel.can_join? == true
    assert panel.can_send? == false
  end

  test "room reads do not create company rooms" do
    human = insert_human!("0xabc0000000000000000000000000000000000003")
    agent = insert_agent!(human, "read-only-room")
    room_key = Rooms.company_room_key(agent)

    refute XMTPMirror.get_room_by_key(room_key)

    assert %{room_key: ^room_key, room_id: nil, ready?: false} =
             CompanyRoomSupport.load_public_room_panel(room_key, human)

    refute XMTPMirror.get_room_by_key(room_key)
  end

  test "joining queues a mirror membership command" do
    room = ensure_room!(Rooms.formation_room_key(), "Formation Room")

    assert {:error, :xmtp_identity_required} =
             XMTPMirror.request_join(
               insert_human!("0xabc0000000000000000000000000000000000004", xmtp?: false),
               %{"room_key" => room.room_key}
             )

    human = insert_human!("0xabc0000000000000000000000000000000000005")

    assert {:ok, result} = XMTPMirror.request_join(human, %{"room_key" => room.room_key})
    assert result.status == "pending"

    command = Repo.get_by!(XmtpMembershipCommand, room_id: room.id, human_user_id: human.id)
    assert command.op == "add_member"
    assert command.status == "pending"
    assert command.xmtp_inbox_id == human.xmtp_inbox_id
  end

  test "one human cannot join two rooms at the same time" do
    first_room = ensure_room!(Rooms.formation_room_key(), "Formation Room")
    second_room = ensure_room!("company:second-room", "Second Room")
    human = insert_human!("0xabc0000000000000000000000000000000000010")

    join_human!(human, first_room)

    assert {:error, :already_in_room} =
             XMTPMirror.request_join(human, %{"room_key" => second_room.room_key})
  end

  test "only joined mirror members can post" do
    room = ensure_room!(Rooms.formation_room_key(), "Formation Room")

    assert {:error, :xmtp_identity_required} =
             XMTPMirror.create_human_message(
               insert_human!("0xabc0000000000000000000000000000000000006", xmtp?: false),
               %{"room_key" => room.room_key, "body" => "hello"}
             )

    assert {:error, :xmtp_membership_required} =
             XMTPMirror.create_human_message(
               insert_human!("0xabc0000000000000000000000000000000000007"),
               %{"room_key" => room.room_key, "body" => "hello"}
             )

    human = insert_human!("0xabc0000000000000000000000000000000000008")
    join_human!(human, room)

    :ok = PublicEvents.subscribe()

    assert {:ok, message} =
             XMTPMirror.create_human_message(human, %{
               "room_key" => room.room_key,
               "body" => "Getting my launch checklist ready."
             })

    assert message.body == "Getting my launch checklist ready."

    assert_receive {:public_site_event,
                    %{
                      event: :xmtp_room_message,
                      room_key: "formation:company-opening",
                      message: %{body: "Getting my launch checklist ready."}
                    }}
  end

  test "heartbeat records presence through the mirror room" do
    room = ensure_room!(Rooms.formation_room_key(), "Formation Room")
    human = insert_human!("0xabc0000000000000000000000000000000000009")

    assert {:ok, %{status: "alive"}} =
             XMTPMirror.heartbeat_presence(human, %{"room_key" => room.room_key})

    presence = Repo.get_by!(XmtpPresence, room_id: room.id, human_user_id: human.id)
    assert presence.xmtp_inbox_id == human.xmtp_inbox_id
    assert DateTime.compare(presence.expires_at, presence.last_seen_at) == :gt
  end

  defp ensure_room!(room_key, name) do
    {:ok, room} =
      XMTPMirror.ensure_room(%{
        "room_key" => room_key,
        "xmtp_group_id" => "xmtp-#{room_key}-#{System.unique_integer([:positive])}",
        "name" => name,
        "status" => "active",
        "presence_ttl_seconds" => 120,
        "capacity" => 200
      })

    room
  end

  defp insert_human!(wallet_address, opts \\ []) do
    xmtp? = Keyword.get(opts, :xmtp?, true)

    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      xmtp_inbox_id:
        if(xmtp?, do: PlatformPhx.XmtpIdentity.deterministic_inbox_id(wallet_address)),
      display_name: "owner@regents.sh"
    })
    |> Repo.insert!()
  end

  defp insert_agent!(human, slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      company_id: insert_company!(human, slug).id,
      template_key: "start",
      name: "Owner Split Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "published",
      public_summary: "Room ownership test company.",
      hero_statement: "Company owner should moderate the room.",
      runtime_status: "ready",
      checkpoint_status: "ready",
      stripe_llm_billing_status: "active",
      stripe_customer_id: "cus_owner_split",
      stripe_pricing_plan_subscription_id: "sub_owner_split",
      sprite_free_until: DateTime.add(now, 86_400, :second),
      sprite_metering_status: "paid",
      wallet_address: human.wallet_address,
      published_at: now,
      desired_runtime_state: "active",
      observed_runtime_state: "active"
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    %Company{}
    |> Company.changeset(%{
      owner_human_id: human.id,
      name: "Owner Split Regent",
      slug: slug,
      claimed_label: slug,
      status: "published",
      public_summary: "Room ownership test company.",
      hero_statement: "Company owner should moderate the room."
    })
    |> Repo.insert!()
  end

  defp join_human!(human, room) do
    %XmtpMembershipCommand{}
    |> XmtpMembershipCommand.enqueue_changeset(%{
      "room_id" => room.id,
      "human_user_id" => human.id,
      "op" => "add_member",
      "xmtp_inbox_id" => human.xmtp_inbox_id,
      "status" => "done"
    })
    |> Repo.insert!()
  end
end
