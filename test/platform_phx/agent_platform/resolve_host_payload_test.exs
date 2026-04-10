defmodule PlatformPhx.AgentPlatform.ResolveHostPayloadTest do
  use PlatformPhx.DataCase, async: true

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  test "paused companies still keep their public Regent hostnames" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-host",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        template_key: "start",
        name: "Paused Regent",
        slug: "paused-host",
        claimed_label: "paused-host",
        basename_fqdn: "paused-host.agent.base.eth",
        ens_fqdn: "paused-host.regent.eth",
        status: "published",
        public_summary: "Paused host test",
        desired_runtime_state: "paused",
        observed_runtime_state: "paused",
        runtime_status: "paused"
      })
      |> Repo.insert!()

    %Subdomain{}
    |> Subdomain.changeset(%{
      agent_id: agent.id,
      slug: agent.slug,
      hostname: "paused-host.regents.sh",
      basename_fqdn: agent.basename_fqdn,
      ens_fqdn: agent.ens_fqdn,
      active: true
    })
    |> Repo.insert!()

    assert {:ok, %{agent: agent}} = AgentPlatform.resolve_host_payload("paused-host.regents.sh")
    assert agent.slug == "paused-host"
    assert agent.subdomain.active == true
  end
end
