defmodule PlatformPhx.AgentPlatform.CompanyTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company

  test "one human can own multiple companies" do
    human = insert_human!("multi-company")

    assert {:ok, first} =
             AgentPlatform.create_company(human, %{
               name: "First Regent",
               slug: "First Regent",
               claimed_label: "first-regent",
               status: "forming",
               public_summary: "First company"
             })

    assert {:ok, second} =
             AgentPlatform.create_company(human, %{
               name: "Second Regent",
               slug: "second-regent",
               claimed_label: "second-regent",
               status: "published",
               public_summary: "Second company"
             })

    companies = AgentPlatform.list_owned_companies(human)

    assert Enum.map(companies, & &1.id) |> Enum.sort() == Enum.sort([first.id, second.id])
    assert AgentPlatform.get_owned_company(human, " FIRST REGENT ").id == first.id
    assert AgentPlatform.get_owned_company(human, second.id).slug == "second-regent"
  end

  test "one company can have multiple agents" do
    human = insert_human!("multi-agent")
    company = insert_company!(human, "shared-company")

    first = insert_agent!(human, company, "shared-agent-one")
    second = insert_agent!(human, company, "shared-agent-two")

    owned_company = AgentPlatform.get_owned_company(human, company.id)

    assert Enum.map(owned_company.agents, & &1.id) |> Enum.sort() ==
             Enum.sort([first.id, second.id])

    assert Repo.preload(first, :company).company.id == company.id
  end

  test "agent creation without an explicit company still links a new company" do
    human = insert_human!("agent-created-company")

    agent =
      %Agent{}
      |> Agent.changeset(agent_attrs(human, "agent-created-company"))
      |> Repo.insert!()
      |> Repo.preload(:company)

    assert %Company{} = agent.company
    assert agent.company_id == agent.company.id
    assert agent.company.owner_human_id == human.id
    assert agent.company.slug == agent.slug
  end

  test "owned agent reads preload the company" do
    human = insert_human!("owned-agent-company")
    company = insert_company!(human, "owned-company")

    insert_agent!(human, company, "owned-company-agent")

    agent = AgentPlatform.get_owned_agent(human, "owned-company-agent")

    assert agent.company.id == company.id
    assert [owned_agent] = AgentPlatform.list_owned_agents(human)
    assert owned_agent.company.id == company.id
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    {:ok, company} =
      AgentPlatform.create_company(human, %{
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{slug} summary"
      })

    company
  end

  defp insert_agent!(human, company, slug) do
    %Agent{}
    |> Agent.changeset(Map.put(agent_attrs(human, slug), :company_id, company.id))
    |> Repo.insert!()
  end

  defp agent_attrs(human, slug) do
    %{
      owner_human_id: human.id,
      template_key: "start",
      name: "#{slug} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "forming",
      public_summary: "#{slug} public summary"
    }
  end
end
