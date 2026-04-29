defmodule PlatformPhx.AgentPlatform.ResolveHostPayloadTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.CompanyProfiles
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  test "paused companies still keep their public Regent hostnames" do
    insert_public_agent!("paused-host",
      name: "Paused Regent",
      public_summary: "Paused host test",
      desired_runtime_state: "paused",
      observed_runtime_state: "paused",
      runtime_status: "paused"
    )

    assert {:ok, %{agent: agent}} = AgentPlatform.resolve_host_payload("paused-host.regents.sh")
    assert agent.slug == "paused-host"
    assert agent.subdomain.active == true
  end

  test "slug and host reads use the same public company profile" do
    insert_public_agent!("shared-profile", name: "Shared Profile")

    assert %{agent: slug_agent, host: "shared-profile.regents.sh"} =
             CompanyProfiles.by_slug("shared-profile")

    assert %{agent: host_agent, host: "shared-profile.regents.sh"} =
             CompanyProfiles.by_host(" Shared-Profile.Regents.SH ")

    assert slug_agent.id == host_agent.id
    assert slug_agent.slug == "shared-profile"
    assert host_agent.slug == "shared-profile"
  end

  test "public resolve payload uses local cache and can be cleared after writes" do
    agent = insert_public_agent!("cached-profile", name: "Cached Profile")

    assert {:ok, payload} = AgentPlatform.resolve_host_payload("cached-profile.regents.sh")
    assert get_in_either(payload, [:agent, :public_summary]) == "Public profile test"

    agent
    |> Agent.changeset(%{public_summary: "Updated profile"})
    |> Repo.update!()

    assert {:ok, cached_payload} = AgentPlatform.resolve_host_payload("cached-profile.regents.sh")
    assert get_in_either(cached_payload, [:agent, :public_summary]) == "Public profile test"

    agent
    |> Repo.preload(:subdomain)
    |> AgentPlatform.clear_public_agent_cache()

    assert {:ok, updated_payload} =
             AgentPlatform.resolve_host_payload("cached-profile.regents.sh")

    assert get_in_either(updated_payload, [:agent, :public_summary]) == "Updated profile"
  end

  test "saving a human avatar clears cached public agent payloads" do
    agent = insert_public_agent!("cached-avatar", name: "Cached Avatar")
    human = Repo.get!(HumanUser, agent.owner_human_id)

    assert {:ok, cached_payload} = AgentPlatform.resolve_host_payload("cached-avatar.regents.sh")
    assert get_in_either(cached_payload, [:agent, :avatar]) == nil

    assert {:ok, _human} =
             AgentPlatform.save_human_avatar(human, %{
               "kind" => "custom_shader",
               "shader_id" => "w3dfWN",
               "define_values" => %{}
             })

    assert {:ok, updated_payload} = AgentPlatform.resolve_host_payload("cached-avatar.regents.sh")
    assert get_in_either(updated_payload, [:agent, :avatar, :shader_id]) == "w3dfWN"
  end

  defp get_in_either(value, []), do: value

  defp get_in_either(value, [key | rest]) when is_map(value) do
    value
    |> Map.get(key, Map.get(value, Atom.to_string(key)))
    |> get_in_either(rest)
  end

  defp insert_public_agent!(slug, attrs) do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-#{slug}",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    agent_attrs =
      attrs
      |> Enum.into(%{})
      |> Map.merge(%{
        owner_human_id: human.id,
        company_id: insert_company!(human, slug, attrs).id,
        template_key: "start",
        name: Keyword.get(attrs, :name, "Public Regent"),
        slug: slug,
        claimed_label: slug,
        basename_fqdn: "#{slug}.agent.base.eth",
        ens_fqdn: "#{slug}.regent.eth",
        status: "published",
        public_summary: Keyword.get(attrs, :public_summary, "Public profile test")
      })

    agent =
      %Agent{}
      |> Agent.changeset(agent_attrs)
      |> Repo.insert!()

    %Subdomain{}
    |> Subdomain.changeset(%{
      agent_id: agent.id,
      slug: agent.slug,
      hostname: "#{slug}.regents.sh",
      basename_fqdn: agent.basename_fqdn,
      ens_fqdn: agent.ens_fqdn,
      active: true
    })
    |> Repo.insert!()

    agent
  end

  defp insert_company!(human, slug, attrs) do
    %Company{}
    |> Company.changeset(%{
      owner_human_id: human.id,
      name: Keyword.get(attrs, :name, "Public Regent"),
      slug: slug,
      claimed_label: slug,
      status: "published",
      public_summary: Keyword.get(attrs, :public_summary, "Public profile test")
    })
    |> Repo.insert!()
  end
end
