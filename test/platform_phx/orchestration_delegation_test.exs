defmodule PlatformPhx.OrchestrationDelegationTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.WorkerAssignment
  alias PlatformPhx.Orchestration
  alias PlatformPhx.RunEvents
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  test "Hermes manager delegates to hosted Codex worker" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("hermes-hosted-codex", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "hermes-hosted-codex")
    link_workers(company, manager, codex)

    assert {:ok, %{target_worker: ^codex, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "codex_exec"),
               actor_context(company, manager)
             )

    assert child_run.company_id == company.id
    assert child_run.parent_run_id == parent_run.id
    assert child_run.root_run_id == parent_run.id
    assert child_run.delegated_by_run_id == parent_run.id
    assert child_run.worker_id == codex.id
    assert child_run.runner_kind == "codex_exec"
    assert [] = assignments_for(child_run)
    assert_enqueued(worker: PlatformPhx.Workers.StartWorkRunJob, args: %{run_id: child_run.id})
  end

  test "OpenClaw manager delegates to hosted Codex worker" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("openclaw-hosted-codex", "openclaw", "openclaw_local_manager")

    codex = hosted_codex_worker(company, "openclaw-hosted-codex")
    link_workers(company, manager, codex)

    assert {:ok, %{target_worker: ^codex, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "codex_exec"),
               actor_context(company, manager)
             )

    assert child_run.worker_id == codex.id
    assert child_run.runner_kind == "codex_exec"
    assert [] = assignments_for(child_run)
    assert_enqueued(worker: PlatformPhx.Workers.StartWorkRunJob, args: %{run_id: child_run.id})
  end

  test "Hermes manager delegates to local OpenClaw executor and creates a local assignment" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("hermes-local-openclaw", "hermes", "hermes_hosted_manager")

    openclaw = local_openclaw_worker(company, "hermes-local-openclaw")
    link_workers(company, manager, openclaw)

    assert {:ok, %{target_worker: ^openclaw, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "openclaw_local_executor"),
               actor_context(company, manager)
             )

    assert child_run.worker_id == openclaw.id
    assert child_run.runner_kind == "openclaw_local_executor"

    assert [%WorkerAssignment{worker_id: worker_id, work_run_id: work_run_id}] =
             assignments_for(child_run)

    assert worker_id == openclaw.id
    assert work_run_id == child_run.id
  end

  test "OpenClaw manager delegates to local OpenClaw executor and creates a local assignment" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("openclaw-local-openclaw", "openclaw", "openclaw_local_manager")

    openclaw = local_openclaw_worker(company, "openclaw-local-openclaw")
    link_workers(company, manager, openclaw)

    assert {:ok, %{target_worker: ^openclaw, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "openclaw_local_executor"),
               actor_context(company, manager)
             )

    assert child_run.worker_id == openclaw.id
    assert child_run.runner_kind == "openclaw_local_executor"
    assert [%WorkerAssignment{}] = assignments_for(child_run)
  end

  test "mixed hosted and local pool filters by requested runner kind and execution surface" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("mixed-pool", "hermes", "hermes_hosted_manager")

    local_openclaw = local_openclaw_worker(company, "mixed-pool-openclaw")
    hosted_codex = hosted_codex_worker(company, "mixed-pool-codex")
    link_workers(company, manager, local_openclaw)
    link_workers(company, manager, hosted_codex)

    payload =
      company
      |> delegation_payload(parent_run, "codex_exec")
      |> Map.put(:execution_surface, "hosted_sprite")

    assert {:ok, %{target_worker: ^hosted_codex, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )

    assert child_run.worker_id == hosted_codex.id
    assert child_run.runner_kind == "codex_exec"
    assert [] = assignments_for(child_run)
  end

  test "delegation rejects eligible workers that do not have a start path" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("unsupported-child-runner", "hermes", "hermes_hosted_manager")

    custom = custom_webhook_worker(company, "unsupported-child-runner")
    link_workers(company, manager, custom)

    payload = delegation_payload(company, parent_run, "custom_worker")

    assert {:error, {:unsupported_runner_kind, "custom_worker"}} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )

    assert WorkRuns.list_child_runs(parent_run.id) == []
  end

  test "delegation can assign a custom local bridge worker" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("custom-local-child", "hermes", "hermes_hosted_manager")

    custom = custom_local_worker(company, "custom-local-child")
    link_workers(company, manager, custom)

    assert {:ok, %{target_worker: ^custom, child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "custom_worker"),
               actor_context(company, manager)
             )

    assert child_run.runner_kind == "custom_worker"
    assert [%WorkerAssignment{}] = assignments_for(child_run)
  end

  test "explicit unlinked target worker is rejected" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("unlinked-target", "hermes", "hermes_hosted_manager")

    linked_openclaw = local_openclaw_worker(company, "unlinked-target-openclaw")
    unlinked_codex = hosted_codex_worker(company, "unlinked-target-codex")
    link_workers(company, manager, linked_openclaw)

    payload =
      company
      |> delegation_payload(parent_run, "codex_exec")
      |> Map.put(:target_worker_id, unlinked_codex.id)

    assert {:error, :target_worker_not_eligible} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )
  end

  test "hosted Codex delegation is rejected when it exceeds the platform-hosted budget" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("hosted-budget-limit", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "hosted-budget-limit")
    link_workers(company, manager, codex)

    {:ok, _policy} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company",
        max_cost_usd_per_run: Decimal.new("1.00")
      })

    payload =
      company
      |> delegation_payload(parent_run, "codex_exec")
      |> Map.put(:budget_limit_usd_cents, 200)

    assert {:error, {:delegation_rejected, %{reason: "budget_limit_exceeded"}}} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )
  end

  test "delegation child run limit counts every requested task before creating runs" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("delegation-child-limit", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "delegation-child-limit")
    link_workers(company, manager, codex)

    {:ok, _policy} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company",
        max_child_runs_per_root_run: 1
      })

    payload =
      company
      |> delegation_payload(parent_run, "codex_exec")
      |> Map.put(:tasks, [
        %{title: "First child run"},
        %{title: "Second child run"}
      ])

    assert {:error, {:approval_required, %{reason: "budget_child_run_limit"}}} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )

    assert WorkRuns.list_child_runs(parent_run.id) == []
  end

  test "delegation protected action inside a task is held for approval" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("delegation-protected-task", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "delegation-protected-task")
    link_workers(company, manager, codex)

    payload =
      company
      |> delegation_payload(parent_run, "codex_exec")
      |> Map.put(:tasks, [
        %{
          title: "Change billing settings",
          metadata: %{action: "billing_change"}
        }
      ])

    assert {:error, {:approval_required, %{reason: "protected_work"}}} =
             Orchestration.handle_delegation_request(
               parent_run,
               payload,
               actor_context(company, manager)
             )

    assert WorkRuns.list_child_runs(parent_run.id) == []
  end

  test "parent events describe delegation without task instructions" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("event-payload", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "event-payload")
    link_workers(company, manager, codex)

    assert {:ok, %{child_runs: [_child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "codex_exec"),
               actor_context(company, manager)
             )

    [requested, accepted, created] = RunEvents.list_events(company.id, parent_run.id)

    assert requested.kind == "delegation.requested"
    assert requested.payload["requested_runner_kind"] == "codex_exec"
    assert requested.payload["task_count"] == 1
    refute Map.has_key?(requested.payload, "tasks")
    refute Map.has_key?(requested.payload, "instructions")

    assert accepted.kind == "delegation.accepted"
    assert accepted.payload["child_run_count"] == 1

    assert created.kind == "child_run.created"
    assert created.payload["runner_kind"] == "codex_exec"
  end

  test "parent receives child completion event once when delegated child completes" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("child-completed-fanout", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "child-completed-fanout")
    link_workers(company, manager, codex)

    assert {:ok, %{child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "codex_exec"),
               actor_context(company, manager)
             )

    assert {:ok, completed_child} =
             WorkRuns.complete_run(child_run, %{summary: "Child finished the review."})

    assert {:ok, _same_child} =
             WorkRuns.complete_run(completed_child, %{summary: "Child finished the review again."})

    completed_events =
      parent_run
      |> parent_event_kinds(company.id, "child_run.completed")

    assert [event] = completed_events
    assert event.payload["root_run_id"] == parent_run.id
    assert event.payload["parent_run_id"] == parent_run.id
    assert event.payload["child_run_id"] == child_run.id
    assert event.payload["child_status"] == "completed"
    assert event.payload["runner_kind"] == "codex_exec"
    assert event.payload["worker_id"] == codex.id
    assert event.payload["summary"] == "Child finished the review."
  end

  test "parent receives child failure event once when delegated child fails" do
    %{company: company, manager: manager, parent_run: parent_run} =
      manager_context("child-failed-fanout", "hermes", "hermes_hosted_manager")

    codex = hosted_codex_worker(company, "child-failed-fanout")
    link_workers(company, manager, codex)

    assert {:ok, %{child_runs: [child_run]}} =
             Orchestration.handle_delegation_request(
               parent_run,
               delegation_payload(company, parent_run, "codex_exec"),
               actor_context(company, manager)
             )

    assert {:ok, failed_child} = WorkRuns.fail_run(child_run, "Child could not finish.")
    assert {:ok, _same_child} = WorkRuns.fail_run(failed_child, "Child failed again.")

    failed_events =
      parent_run
      |> parent_event_kinds(company.id, "child_run.failed")

    assert [event] = failed_events
    assert event.payload["root_run_id"] == parent_run.id
    assert event.payload["parent_run_id"] == parent_run.id
    assert event.payload["child_run_id"] == child_run.id
    assert event.payload["child_status"] == "failed"
    assert event.payload["runner_kind"] == "codex_exec"
    assert event.payload["worker_id"] == codex.id
    assert event.payload["failure_reason"] == "Child could not finish."
  end

  defp manager_context(key, agent_kind, runner_kind) do
    human = insert_human!(key)
    company = insert_company!(human, key)

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "#{key} manager profile",
        agent_kind: agent_kind,
        default_runner_kind: runner_kind
      })

    {:ok, manager} =
      AgentRegistry.register_worker(%{
        company_id: company.id,
        agent_profile_id: profile.id,
        name: "#{key} manager worker",
        agent_kind: agent_kind,
        worker_role: "manager",
        execution_surface: manager_execution_surface(runner_kind),
        runner_kind: runner_kind,
        billing_mode: manager_billing_mode(runner_kind),
        trust_scope: manager_trust_scope(runner_kind),
        reported_usage_policy: manager_usage_policy(runner_kind)
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: manager.id,
        title: "#{key} parent work",
        status: "running",
        visibility: "operator",
        desired_runner_kind: runner_kind
      })

    {:ok, parent_run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: manager.id,
        runner_kind: runner_kind,
        status: "running",
        visibility: "operator"
      })

    %{human: human, company: company, profile: profile, manager: manager, parent_run: parent_run}
  end

  defp hosted_codex_worker(company, key) do
    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "#{key} codex profile",
        agent_kind: "codex",
        default_runner_kind: "codex_exec"
      })

    {:ok, worker} =
      AgentRegistry.register_worker(%{
        company_id: company.id,
        agent_profile_id: profile.id,
        name: "#{key} codex worker",
        agent_kind: "codex",
        worker_role: "executor",
        execution_surface: "hosted_sprite",
        runner_kind: "codex_exec",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      })

    worker
  end

  defp local_openclaw_worker(company, key) do
    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "#{key} openclaw profile",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_executor"
      })

    {:ok, worker} =
      AgentRegistry.register_openclaw_worker(
        company.id,
        %{
          agent_profile_id: profile.id,
          name: "#{key} openclaw worker",
          worker_role: "executor",
          runner_kind: "openclaw_local_executor"
        },
        %{}
      )

    worker
  end

  defp custom_webhook_worker(company, key) do
    custom_worker(
      company,
      key,
      "external_webhook",
      "external_self_reported",
      "external_user_controlled",
      "external_reported"
    )
  end

  defp custom_local_worker(company, key) do
    custom_worker(
      company,
      key,
      "local_bridge",
      "user_local",
      "local_user_controlled",
      "self_reported"
    )
  end

  defp custom_worker(
         company,
         key,
         execution_surface,
         billing_mode,
         trust_scope,
         reported_usage_policy
       ) do
    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "#{key} custom profile",
        agent_kind: "custom",
        default_runner_kind: "custom_worker"
      })

    {:ok, worker} =
      AgentRegistry.register_worker(%{
        company_id: company.id,
        agent_profile_id: profile.id,
        name: "#{key} custom worker",
        agent_kind: "custom",
        worker_role: "executor",
        execution_surface: execution_surface,
        runner_kind: "custom_worker",
        billing_mode: billing_mode,
        trust_scope: trust_scope,
        reported_usage_policy: reported_usage_policy
      })

    worker
  end

  defp link_workers(company, manager, executor) do
    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_worker_id: manager.id,
               target_worker_id: executor.id,
               relationship_kind: "can_delegate_to"
             })
  end

  defp delegation_payload(company, parent_run, requested_runner_kind) do
    %{
      company_id: company.id,
      run_id: parent_run.id,
      requested_runner_kind: requested_runner_kind,
      strategy: "parallel",
      tasks: [
        %{
          title: "Review the release notes",
          instructions: "Check private draft details before publication.",
          metadata: %{source: "manager"}
        }
      ]
    }
  end

  defp actor_context(company, manager) do
    %{company_id: company.id, worker_id: manager.id, actor_kind: "worker"}
  end

  defp assignments_for(run) do
    WorkerAssignment
    |> where([assignment], assignment.work_run_id == ^run.id)
    |> Repo.all()
  end

  defp parent_event_kinds(parent_run, company_id, kind) do
    company_id
    |> RunEvents.list_events(parent_run.id)
    |> Enum.filter(&(&1.kind == kind))
  end

  defp manager_execution_surface("openclaw_local_manager"), do: "local_bridge"
  defp manager_execution_surface(_runner_kind), do: "hosted_sprite"

  defp manager_billing_mode("openclaw_local_manager"), do: "user_local"
  defp manager_billing_mode(_runner_kind), do: "platform_hosted"

  defp manager_trust_scope("openclaw_local_manager"), do: "local_user_controlled"
  defp manager_trust_scope(_runner_kind), do: "platform_hosted"

  defp manager_usage_policy("openclaw_local_manager"), do: "self_reported"
  defp manager_usage_policy(_runner_kind), do: "platform_metered"

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-orchestration-delegation-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, key) do
    slug = "orchestration-delegation-#{key}-#{System.unique_integer([:positive])}"

    {:ok, company} =
      PlatformPhx.AgentPlatform.Companies.create_company(human, %{
        name: "#{key} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{key} summary"
      })

    company
  end
end
