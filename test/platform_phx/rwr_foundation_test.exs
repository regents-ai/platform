defmodule PlatformPhx.RwrFoundationTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentRelationship
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.RunEvents

  test "inserts owned runtime, agent, work, run, event, artifact, approval, usage, and assignment records" do
    %{company: company, profile: profile, worker: worker, runtime: runtime} =
      company_runtime_fixture()

    {:ok, service} =
      RuntimeRegistry.create_runtime_service(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        name: "local bridge",
        service_kind: "bridge"
      })

    {:ok, budget} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company",
        max_child_runs_per_root_run: 3
      })

    {:ok, goal} =
      Work.create_goal(%{
        company_id: company.id,
        owner_agent_profile_id: profile.id,
        budget_policy_id: budget.id,
        title: "Prepare launch"
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        goal_id: goal.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: worker.id,
        budget_policy_id: budget.id,
        title: "Draft operator notes",
        desired_runner_kind: "openclaw_local_executor"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runtime_profile_id: runtime.id,
        runner_kind: "openclaw_local_executor"
      })

    {:ok, event} =
      RunEvents.append_event(%{
        company_id: company.id,
        run_id: run.id,
        sequence: 1,
        kind: "run.started"
      })

    {:ok, artifact} =
      WorkRuns.create_artifact(%{
        company_id: company.id,
        work_item_id: item.id,
        run_id: run.id,
        kind: "proof_packet",
        title: "Local proof"
      })

    {:ok, approval} =
      WorkRuns.create_approval_request(%{
        company_id: company.id,
        work_run_id: run.id,
        kind: "protected_action",
        requested_by_actor_kind: "worker"
      })

    {:ok, checkpoint} =
      RuntimeRegistry.create_runtime_checkpoint(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        work_run_id: run.id,
        checkpoint_ref: "local-self-report"
      })

    {:ok, usage} =
      RuntimeRegistry.create_usage_snapshot(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        snapshot_at: DateTime.utc_now() |> DateTime.truncate(:second),
        provider: "openclaw_local"
      })

    {:ok, assignment} =
      AgentRegistry.assign_worker(%{
        company_id: company.id,
        worker_id: worker.id,
        work_run_id: run.id
      })

    assert service.company_id == company.id
    assert event.visibility == "operator"
    assert artifact.visibility == "operator"
    assert artifact.attestation_level == "local_self_reported"
    assert approval.status == "pending"
    assert checkpoint.protected == false
    assert usage.estimated_cost_usd == Decimal.new("0")
    assert assignment.company_id == company.id
    assert [^event] = RunEvents.list_events(run.id)
  end

  test "validates contract enum values and relationship kinds" do
    %{company: company, profile: profile, worker: worker} = company_runtime_fixture()

    assert %{valid?: false} =
             AgentWorker.changeset(%AgentWorker{}, %{
               company_id: company.id,
               agent_profile_id: profile.id,
               name: "Bad worker",
               agent_kind: "openclaw",
               worker_role: "executor",
               execution_surface: "local_bridge",
               runner_kind: "openclaw_local_executor",
               billing_mode: "hosted",
               trust_scope: "local_user_controlled",
               reported_usage_policy: "self_reported"
             })

    assert %{valid?: false} =
             AgentRelationship.changeset(%AgentRelationship{}, %{
               company_id: company.id,
               source_worker_id: worker.id,
               target_worker_id: worker.id,
               relationship_kind: "parallel_runner"
             })

    assert {:ok, relationship} =
             AgentRegistry.create_relationship(%{
               company_id: company.id,
               source_agent_profile_id: profile.id,
               target_worker_id: worker.id,
               relationship_kind: "can_delegate_to",
               max_parallel_runs: 2
             })

    assert relationship.relationship_kind == "can_delegate_to"
    assert relationship.max_parallel_runs == 2

    assert {:ok, default_relationship} =
             AgentRegistry.create_relationship(%{
               company_id: company.id,
               source_agent_profile_id: profile.id,
               target_worker_id: worker.id,
               relationship_kind: "preferred_executor"
             })

    assert default_relationship.max_parallel_runs == 1
  end

  test "local OpenClaw workers default to user-local billing and operator-only proof visibility" do
    human = insert_human!("openclaw-defaults")
    company = insert_company!(human, "openclaw-defaults")

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "Local OpenClaw",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_manager"
      })

    assert {:ok, worker} =
             AgentRegistry.register_worker(%{
               company_id: company.id,
               agent_profile_id: profile.id,
               name: "Local OpenClaw Worker",
               agent_kind: "openclaw",
               worker_role: "manager",
               execution_surface: "local_bridge",
               runner_kind: "openclaw_local_manager"
             })

    assert worker.billing_mode == "user_local"
    assert worker.trust_scope == "local_user_controlled"
    assert worker.reported_usage_policy == "self_reported"
  end

  defp company_runtime_fixture do
    human = insert_human!(System.unique_integer([:positive]))
    company = insert_company!(human, "rwr-#{System.unique_integer([:positive])}")

    {:ok, runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "Local OpenClaw",
        runner_kind: "openclaw_local_executor",
        execution_surface: "local_bridge"
      })

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "OpenClaw Executor",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_executor"
      })

    {:ok, worker} =
      AgentRegistry.register_worker(%{
        company_id: company.id,
        agent_profile_id: profile.id,
        runtime_profile_id: runtime.id,
        name: "OpenClaw Executor Worker",
        agent_kind: "openclaw",
        worker_role: "executor",
        execution_surface: "local_bridge",
        runner_kind: "openclaw_local_executor"
      })

    %{human: human, company: company, runtime: runtime, profile: profile, worker: worker}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-rwr-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    {:ok, company} =
      PlatformPhx.AgentPlatform.Companies.create_company(human, %{
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{slug} summary"
      })

    company
  end
end
