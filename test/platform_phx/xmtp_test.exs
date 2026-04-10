defmodule PlatformPhx.XmtpTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.Repo
  alias PlatformPhx.Xmtp
  alias RegentXmtpRoom.Room

  test "company rooms keep the Regent room agent as owner while the company owner is moderator" do
    human = insert_human!("0xabc0000000000000000000000000000000000001")
    agent = insert_agent!(human, "owner-split")

    assert {:ok, room_info} = Xmtp.bootstrap_company_room!(agent, reuse: true)

    room = Repo.get_by!(Room, room_key: Xmtp.company_room_key(agent))
    assert room.agent_inbox_id == room_info.agent_inbox_id

    assert {:ok, owner_panel} = Xmtp.company_room_panel(human, agent)
    assert owner_panel.moderator? == true
    assert owner_panel.connected_wallet == String.downcase(human.wallet_address)
  end

  defp insert_human!(wallet_address) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      display_name: "owner@regents.sh"
    })
    |> Repo.insert!()
  end

  defp insert_agent!(human, slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      template_key: "start",
      name: "Owner Split Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "published",
      public_summary: "Room ownership test company.",
      hero_statement:
        "Company owner should moderate the room while the Regent room agent owns it.",
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
end
