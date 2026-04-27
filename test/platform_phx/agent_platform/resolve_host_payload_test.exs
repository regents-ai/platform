defmodule PlatformPhx.AgentPlatform.ResolveHostPayloadTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.CompanyProfiles
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_dragonfly_enabled = Application.get_env(:platform_phx, :dragonfly_enabled)
    previous_dragonfly_name = Application.get_env(:platform_phx, :dragonfly_name)

    previous_dragonfly_command_module =
      Application.get_env(:platform_phx, :dragonfly_command_module)

    on_exit(fn ->
      restore_app_env(:platform_phx, :dragonfly_enabled, previous_dragonfly_enabled)
      restore_app_env(:platform_phx, :dragonfly_name, previous_dragonfly_name)
      restore_app_env(:platform_phx, :dragonfly_command_module, previous_dragonfly_command_module)
      Process.delete(:dragonfly_values)
    end)

    :ok
  end

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

  test "public resolve payload uses Dragonfly and can be cleared after writes" do
    configure_fake_cache(%{})
    agent = insert_public_agent!("cached-profile", name: "Cached Profile")

    assert {:ok, %{agent: %{public_summary: "Public profile test"}}} =
             AgentPlatform.resolve_host_payload("cached-profile.regents.sh")

    agent
    |> Agent.changeset(%{public_summary: "Updated profile"})
    |> Repo.update!()

    assert {:ok, %{agent: %{public_summary: "Public profile test"}}} =
             AgentPlatform.resolve_host_payload("cached-profile.regents.sh")

    agent
    |> Repo.preload(:subdomain)
    |> AgentPlatform.clear_public_agent_cache()

    assert {:ok, %{agent: %{public_summary: "Updated profile"}}} =
             AgentPlatform.resolve_host_payload("cached-profile.regents.sh")
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

  defp configure_fake_cache(values) do
    Application.put_env(:platform_phx, :dragonfly_enabled, true)
    Application.put_env(:platform_phx, :dragonfly_name, self())
    Application.put_env(:platform_phx, :dragonfly_command_module, __MODULE__.FakeRedix)
    Process.put(:dragonfly_values, values)
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defmodule FakeRedix do
    def command(_owner, ["GET", key]) do
      {:ok, Map.get(Process.get(:dragonfly_values, %{}), key)}
    end

    def command(_owner, ["SET", key, value, "EX", _ttl]) do
      values = Process.get(:dragonfly_values, %{})
      Process.put(:dragonfly_values, Map.put(values, key, value))
      {:ok, "OK"}
    end

    def command(_owner, ["DEL" | keys]) do
      values = Process.get(:dragonfly_values, %{})
      Process.put(:dragonfly_values, Map.drop(values, keys))
      {:ok, length(keys)}
    end

    def command(_owner, ["PING"]), do: {:ok, "PONG"}
  end
end
