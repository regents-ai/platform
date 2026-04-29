defmodule PlatformPhx.AgentPlatform.FormationProgressTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.FormationEvent
  alias PlatformPhx.AgentPlatform.FormationProgress
  alias PlatformPhx.AgentPlatform.FormationRun

  test "insert_and_broadcast! persists progress before publishing it" do
    formation = insert_formation!("progress-one")

    :ok = FormationProgress.subscribe(formation.id)

    event =
      FormationProgress.insert_and_broadcast!(
        formation,
        "verify_runtime",
        "started",
        "We're checking that your company is responding."
      )

    assert Repo.get!(FormationEvent, event.id).message ==
             "We're checking that your company is responding."

    assert_receive {:formation_progress,
                    %{
                      formation_id: formation_id,
                      agent_id: agent_id,
                      claimed_label: "progress-one",
                      event: %{
                        step: "verify_runtime",
                        status: "started",
                        message: "We're checking that your company is responding."
                      }
                    }}

    assert formation_id == formation.id
    assert agent_id == formation.agent_id
  end

  test "progress broadcasts stay on the formation topic" do
    subscribed_formation = insert_formation!("subscribed-progress")
    other_formation = insert_formation!("other-progress")

    :ok = FormationProgress.subscribe(subscribed_formation.id)

    FormationProgress.insert_and_broadcast!(
      other_formation,
      "create_sprite",
      "started",
      "We're setting up your company now."
    )

    refute_receive {:formation_progress, _payload}, 50
  end

  defp insert_formation!(slug) do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-#{slug}-#{System.unique_integer([:positive])}",
        wallet_address: "0x1111111111111111111111111111111111111111",
        wallet_addresses: ["0x1111111111111111111111111111111111111111"],
        display_name: "operator@regents.sh",
        stripe_llm_billing_status: "active"
      })
      |> Repo.insert!()

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: insert_company!(human, slug).id,
        template_key: "start",
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        basename_fqdn: "#{slug}.agent.base.eth",
        status: "forming",
        public_summary: "Test company",
        hero_statement: "Test company",
        sprite_name: "#{slug}-sprite",
        runtime_status: "forming",
        checkpoint_status: "pending",
        stripe_llm_billing_status: "active",
        wallet_address: human.wallet_address,
        desired_runtime_state: "active",
        observed_runtime_state: "unknown"
      })
      |> Repo.insert!()

    %FormationRun{}
    |> FormationRun.changeset(%{
      agent_id: agent.id,
      human_user_id: human.id,
      claimed_label: slug,
      status: "running",
      current_step: "create_sprite"
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    %Company{}
    |> Company.changeset(%{
      owner_human_id: human.id,
      name: "#{slug} Regent",
      slug: slug,
      claimed_label: slug,
      status: "forming",
      public_summary: "Test company"
    })
    |> Repo.insert!()
  end
end
