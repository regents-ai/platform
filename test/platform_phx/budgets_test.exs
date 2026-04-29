defmodule PlatformPhx.BudgetsTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.Budgets
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  test "hosted Codex work uses platform-hosted budget checks" do
    %{company: company, item: item, worker: worker, policy: policy} =
      work_fixture("codex-hosted",
        runner_kind: "codex_exec",
        agent_kind: "codex",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      )

    assert {:ok, decision} =
             Budgets.check_run_request(%{
               company_id: company.id,
               work_item_id: item.id,
               worker_id: worker.id,
               estimated_cost_usd: Decimal.new("4.50"),
               estimated_runtime_minutes: 15
             })

    assert decision.hosted_compute == true
    assert decision.usage_accounting == "platform_metered"
    assert decision.policy_id == policy.id
  end

  test "hosted work outside hard limits is rejected" do
    %{company: company, item: item, worker: worker} =
      work_fixture("codex-rejected",
        runner_kind: "codex_exec",
        agent_kind: "codex",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      )

    assert {:rejected, %{reason: "budget_limit_exceeded"}} =
             Budgets.check_run_request(%{
               company_id: company.id,
               work_item_id: item.id,
               worker_id: worker.id,
               estimated_cost_usd: Decimal.new("12.00"),
               estimated_runtime_minutes: 15
             })
  end

  test "local OpenClaw work is not counted as hosted compute" do
    %{company: company, item: item, worker: worker} =
      work_fixture("openclaw-local",
        runner_kind: "openclaw_local_executor",
        agent_kind: "openclaw",
        execution_surface: "local_bridge"
      )

    assert {:ok, decision} =
             Budgets.check_run_request(%{
               company_id: company.id,
               work_item_id: item.id,
               worker_id: worker.id,
               estimated_cost_usd: Decimal.new("50.00"),
               estimated_runtime_minutes: 500
             })

    assert decision.hosted_compute == false
    assert decision.usage_accounting == "self_reported"
    assert decision.billing_mode == "user_local"
  end

  test "protected work requires approval and creates an approval request when a run exists" do
    %{company: company, item: item, worker: worker} =
      work_fixture("protected-work",
        runner_kind: "codex_exec",
        agent_kind: "codex",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      )

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: "codex_exec"
      })

    assert {:approval_required, decision} =
             Budgets.check_delegation_request(%{
               company_id: company.id,
               work_item_id: item.id,
               work_run_id: run.id,
               worker_id: worker.id,
               action: "deploy",
               requested_by_actor_kind: "worker",
               requested_by_actor_id: Integer.to_string(worker.id)
             })

    assert decision.reason == "protected_work"
    assert decision.approval_request.status == "pending"
    assert decision.approval_request.kind == "protected_work"
    assert decision.approval_request.payload["protected_action"] == "deploy"
  end

  test "protected work inside delegated task metadata requires approval" do
    %{company: company, item: item, worker: worker} =
      work_fixture("protected-task-work",
        runner_kind: "codex_exec",
        agent_kind: "codex",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      )

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: "codex_exec"
      })

    assert {:approval_required, decision} =
             Budgets.check_delegation_request(%{
               company_id: company.id,
               work_item_id: item.id,
               work_run_id: run.id,
               root_run_id: run.id,
               worker_id: worker.id,
               requested_by_actor_kind: "worker",
               requested_by_actor_id: Integer.to_string(worker.id),
               tasks: [
                 %{
                   title: "Update payment settings",
                   metadata: %{action: "billing_change"}
                 }
               ]
             })

    assert decision.reason == "protected_work"
    assert decision.approval_request.payload["protected_action"] == "billing_change"
  end

  test "child run limit counts every requested delegated task" do
    %{company: company, item: item, worker: worker} =
      work_fixture("child-run-count",
        runner_kind: "codex_exec",
        agent_kind: "codex",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered",
        max_child_runs_per_root_run: 1
      )

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: "codex_exec"
      })

    assert {:approval_required, decision} =
             Budgets.check_delegation_request(%{
               company_id: company.id,
               work_item_id: item.id,
               work_run_id: run.id,
               root_run_id: run.id,
               worker_id: worker.id,
               requested_by_actor_kind: "worker",
               requested_by_actor_id: Integer.to_string(worker.id),
               tasks: [
                 %{title: "First child run"},
                 %{title: "Second child run"}
               ]
             })

    assert decision.reason == "budget_child_run_limit"
  end

  defp work_fixture(key, opts) do
    human = insert_human!(key)
    company = insert_company!(human, key)
    runner_kind = Keyword.fetch!(opts, :runner_kind)
    agent_kind = Keyword.fetch!(opts, :agent_kind)
    execution_surface = Keyword.fetch!(opts, :execution_surface)

    {:ok, runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "#{key} runtime",
        runner_kind: runner_kind,
        execution_surface: execution_surface,
        billing_mode: Keyword.get(opts, :billing_mode, "user_local")
      })

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "#{key} profile",
        agent_kind: agent_kind,
        default_runner_kind: runner_kind
      })

    worker_attrs =
      %{
        company_id: company.id,
        agent_profile_id: profile.id,
        runtime_profile_id: runtime.id,
        name: "#{key} worker",
        agent_kind: agent_kind,
        worker_role: "executor",
        execution_surface: execution_surface,
        runner_kind: runner_kind
      }
      |> maybe_put(:billing_mode, Keyword.get(opts, :billing_mode))
      |> maybe_put(:trust_scope, Keyword.get(opts, :trust_scope))
      |> maybe_put(:reported_usage_policy, Keyword.get(opts, :reported_usage_policy))

    {:ok, worker} = AgentRegistry.register_worker(worker_attrs)

    {:ok, policy} =
      Work.create_budget_policy(%{
        company_id: company.id,
        scope_kind: "company",
        max_cost_usd_per_run: Decimal.new("10.00"),
        max_runtime_minutes_per_run: 60,
        requires_approval_over_usd: Decimal.new("7.00"),
        max_child_runs_per_root_run: Keyword.get(opts, :max_child_runs_per_root_run, 3)
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: worker.id,
        budget_policy_id: policy.id,
        title: "#{key} work",
        desired_runner_kind: runner_kind
      })

    %{company: company, item: item, worker: worker, policy: policy}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-budget-#{key}",
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
