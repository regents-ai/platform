defmodule PlatformPhx.AgentRegistryTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  test "OpenClaw registration sets local defaults and validates enum values" do
    %{company: company, profile: profile} = company_fixture("openclaw-registration")

    assert {:ok, worker} =
             AgentRegistry.register_openclaw_worker(
               company.id,
               %{
                 agent_profile_id: profile.id,
                 name: "Local OpenClaw",
                 worker_role: "executor",
                 runner_kind: "openclaw_local_executor"
               },
               %{subject: "local-openclaw"}
             )

    assert worker.agent_kind == "openclaw"
    assert worker.execution_surface == "local_bridge"
    assert worker.billing_mode == "user_local"
    assert worker.trust_scope == "local_user_controlled"
    assert worker.reported_usage_policy == "self_reported"

    assert {:error, hosted_openclaw} =
             AgentRegistry.register_openclaw_worker(
               company.id,
               %{
                 "agent_profile_id" => profile.id,
                 "name" => "Hosted value rejected",
                 "worker_role" => "executor",
                 "runner_kind" => "openclaw_local_executor",
                 "execution_surface" => "hosted_sprite",
                 "billing_mode" => "platform_hosted",
                 "trust_scope" => "platform_hosted",
                 "reported_usage_policy" => "platform_metered"
               },
               %{}
             )

    refute hosted_openclaw.valid?
    assert %{execution_surface: [_], billing_mode: [_]} = errors_on(hosted_openclaw)

    changeset =
      AgentWorker.changeset(%AgentWorker{}, %{
        company_id: company.id,
        agent_profile_id: profile.id,
        name: "Bad local OpenClaw",
        agent_kind: "openclaw",
        worker_role: "executor",
        execution_surface: "local_bridge",
        runner_kind: "not_real"
      })

    refute changeset.valid?
    assert %{runner_kind: [_message]} = errors_on(changeset)
  end

  test "worker validation keeps OpenClaw local and Codex hosted" do
    %{company: company, profile: openclaw_profile} = company_fixture("worker-shape")

    {:ok, codex_profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "worker-shape codex profile",
        agent_kind: "codex",
        default_runner_kind: "codex_exec"
      })

    hosted_openclaw =
      AgentWorker.changeset(%AgentWorker{}, %{
        company_id: company.id,
        agent_profile_id: openclaw_profile.id,
        name: "Hosted OpenClaw",
        agent_kind: "openclaw",
        worker_role: "executor",
        execution_surface: "hosted_sprite",
        runner_kind: "openclaw_local_executor",
        billing_mode: "platform_hosted",
        trust_scope: "platform_hosted",
        reported_usage_policy: "platform_metered"
      })

    refute hosted_openclaw.valid?
    assert %{execution_surface: [_], billing_mode: [_]} = errors_on(hosted_openclaw)

    local_codex =
      AgentWorker.changeset(%AgentWorker{}, %{
        company_id: company.id,
        agent_profile_id: codex_profile.id,
        name: "Local Codex",
        agent_kind: "codex",
        worker_role: "executor",
        execution_surface: "local_bridge",
        runner_kind: "codex_exec",
        billing_mode: "user_local",
        trust_scope: "local_user_controlled",
        reported_usage_policy: "self_reported"
      })

    refute local_codex.valid?
    assert %{execution_surface: [_], billing_mode: [_]} = errors_on(local_codex)
  end

  test "worker registration accepts request-shaped hosted Codex attrs" do
    %{company: company} = company_fixture("worker-request-shape")

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "worker-request-shape codex profile",
        agent_kind: "codex",
        default_runner_kind: "codex_exec"
      })

    assert {:ok, worker} =
             AgentRegistry.register_worker(
               company.id,
               %{
                 "agent_profile_id" => profile.id,
                 "name" => "Hosted Codex",
                 "agent_kind" => "codex",
                 "worker_role" => "executor",
                 "execution_surface" => "hosted_sprite",
                 "runner_kind" => "codex_exec",
                 "billing_mode" => "platform_hosted",
                 "trust_scope" => "platform_hosted",
                 "reported_usage_policy" => "platform_metered"
               },
               %{}
             )

    assert worker.company_id == company.id
    assert worker.agent_kind == "codex"
    assert worker.execution_surface == "hosted_sprite"
    assert worker.reported_usage_policy == "platform_metered"
  end

  test "heartbeat updates only a worker owned by the same company" do
    %{company: company, worker: worker} = worker_fixture("heartbeat-owned")
    %{company: other_company} = company_fixture("heartbeat-other")

    assert {:ok, updated} =
             AgentRegistry.heartbeat_worker(company.id, worker.id, %{
               "connection_metadata" => %{bridge_pid: "local-1"}
             })

    assert updated.status == "active"
    assert updated.last_heartbeat_at
    assert updated.connection_metadata == %{bridge_pid: "local-1"}

    assert {:error, :not_found} =
             AgentRegistry.heartbeat_worker(other_company.id, worker.id, %{"status" => "active"})
  end

  test "assignment listing and claiming are scoped to the assigned worker" do
    %{company: company, profile: profile, worker: worker} = worker_fixture("assignment-owner")
    %{worker: other_worker} = worker_fixture("assignment-other", company: company)

    {:ok, assignment} = assignment_fixture(company, profile, worker, "owner assignment")

    {:ok, other_assignment} =
      assignment_fixture(company, profile, other_worker, "other assignment")

    assert [listed] = AgentRegistry.list_worker_assignments(company.id, worker.id)
    assert listed.id == assignment.id

    assert {:error, :not_found} =
             AgentRegistry.claim_worker_assignment(company.id, other_worker.id, assignment.id)

    assert {:ok, claimed} =
             AgentRegistry.claim_worker_assignment(company.id, worker.id, assignment.id)

    assert claimed.status == "claimed"
    assert claimed.claimed_at

    assert [^other_assignment] =
             AgentRegistry.list_worker_assignments(company.id, other_worker.id)
  end

  test "assignments can be released and completed by the assigned worker" do
    %{company: company, profile: profile, worker: worker} = worker_fixture("assignment-lifecycle")

    {:ok, release_assignment} = assignment_fixture(company, profile, worker, "release assignment")

    assert {:ok, released} =
             AgentRegistry.release_worker_assignment(company.id, worker.id, release_assignment.id)

    assert released.status == "released"
    assert released.released_at

    {:ok, complete_assignment} =
      assignment_fixture(company, profile, worker, "complete assignment")

    assert {:ok, completed} =
             AgentRegistry.complete_worker_assignment(
               company.id,
               worker.id,
               complete_assignment.id
             )

    assert completed.status == "completed"
    assert completed.released_at
  end

  test "assignment creation requires the run to belong to the worker company" do
    %{company: company, worker: worker} = worker_fixture("assignment-run-company")

    %{company: other_company, profile: other_profile, worker: other_worker} =
      worker_fixture("assignment-run-other")

    {:ok, item} =
      Work.create_item(%{
        company_id: other_company.id,
        assigned_agent_profile_id: other_profile.id,
        assigned_worker_id: other_worker.id,
        title: "Other company work",
        desired_runner_kind: other_worker.runner_kind
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: other_company.id,
        work_item_id: item.id,
        worker_id: other_worker.id,
        runner_kind: other_worker.runner_kind
      })

    assert {:error, :run_not_found} =
             AgentRegistry.create_worker_assignment(company.id, worker.id, %{work_run_id: run.id})
  end

  test "assignment creation requires the run to be assigned to the worker" do
    %{company: company, worker: worker} = worker_fixture("assignment-worker-match")

    %{profile: other_profile, worker: other_worker} =
      worker_fixture("assignment-worker-other", company: company)

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: other_profile.id,
        assigned_worker_id: other_worker.id,
        title: "Other worker work",
        desired_runner_kind: other_worker.runner_kind
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: other_worker.id,
        runner_kind: other_worker.runner_kind
      })

    assert {:error, :run_worker_mismatch} =
             AgentRegistry.create_worker_assignment(company.id, worker.id, %{work_run_id: run.id})
  end

  test "execution pool returns linked active executor workers and excludes inactive or manager-only links" do
    %{company: company, profile: hermes, worker: hermes_worker} =
      worker_fixture("pool-hermes",
        profile_attrs: %{agent_kind: "hermes", default_runner_kind: "hermes_local_manager"},
        worker_attrs: %{
          agent_kind: "hermes",
          worker_role: "manager",
          runner_kind: "hermes_local_manager"
        }
      )

    %{worker: openclaw_executor} = worker_fixture("pool-openclaw-executor", company: company)

    %{worker: paused_executor} =
      worker_fixture("pool-paused-executor", company: company, worker_attrs: %{status: "active"})

    %{worker: revoked_executor} =
      worker_fixture("pool-revoked-executor", company: company, worker_attrs: %{status: "active"})

    %{worker: manager_only} =
      worker_fixture("pool-manager-only",
        company: company,
        worker_attrs: %{worker_role: "manager", runner_kind: "openclaw_local_manager"}
      )

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_agent_profile_id: hermes.id,
               target_worker_id: openclaw_executor.id,
               relationship_kind: "preferred_executor"
             })

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_worker_id: hermes_worker.id,
               target_worker_id: paused_executor.id,
               relationship_kind: "can_delegate_to",
               status: "paused"
             })

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_agent_profile_id: hermes.id,
               target_worker_id: revoked_executor.id,
               relationship_kind: "can_delegate_to",
               status: "revoked"
             })

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_agent_profile_id: hermes.id,
               target_worker_id: manager_only.id,
               relationship_kind: "manager_of"
             })

    pool = AgentRegistry.list_execution_pool(company.id, hermes.id)

    assert Enum.map(pool, & &1.id) == [openclaw_executor.id]
  end

  test "execution pool excludes stale workers without changing them during reads" do
    %{company: company, profile: hermes} =
      worker_fixture("pool-capabilities-manager",
        profile_attrs: %{agent_kind: "hermes", default_runner_kind: "hermes_local_manager"},
        worker_attrs: %{
          agent_kind: "hermes",
          worker_role: "manager",
          runner_kind: "hermes_local_manager"
        }
      )

    stale_heartbeat =
      DateTime.utc_now()
      |> DateTime.add(-120, :second)
      |> DateTime.truncate(:second)

    %{worker: stale_worker} =
      worker_fixture("pool-stale-worker",
        company: company,
        worker_attrs: %{
          status: "active",
          last_heartbeat_at: stale_heartbeat,
          heartbeat_ttl_seconds: 30,
          capabilities: ["code"]
        }
      )

    %{worker: capable_worker} =
      worker_fixture("pool-capable-worker",
        company: company,
        worker_attrs: %{capabilities: ["code", "browser"]}
      )

    for worker <- [stale_worker, capable_worker] do
      assert {:ok, _relationship} =
               AgentRegistry.create_agent_relationship(company.id, %{
                 source_agent_profile_id: hermes.id,
                 target_worker_id: worker.id,
                 relationship_kind: "can_delegate_to"
               })
    end

    pool =
      AgentRegistry.list_execution_pool(company.id, hermes.id,
        delegation_payload: %{"required_capabilities" => ["browser"]}
      )

    assert Enum.map(pool, & &1.id) == [capable_worker.id]
    assert AgentRegistry.get_worker(company.id, stale_worker.id).status == "active"
  end

  test "execution pool respects relationship capacity" do
    %{company: company, profile: hermes} =
      worker_fixture("pool-capacity-manager",
        profile_attrs: %{agent_kind: "hermes", default_runner_kind: "hermes_local_manager"},
        worker_attrs: %{
          agent_kind: "hermes",
          worker_role: "manager",
          runner_kind: "hermes_local_manager"
        }
      )

    %{profile: executor_profile, worker: executor} =
      worker_fixture("pool-capacity-executor", company: company)

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_agent_profile_id: hermes.id,
               target_worker_id: executor.id,
               relationship_kind: "can_delegate_to",
               max_parallel_runs: 1
             })

    {:ok, assignment} =
      assignment_fixture(company, executor_profile, executor, "capacity assignment")

    {:ok, _claimed} =
      AgentRegistry.claim_worker_assignment(company.id, executor.id, assignment.id)

    assert [] = AgentRegistry.list_execution_pool(company.id, hermes.id)
  end

  test "execution pool supports OpenClaw manager to OpenClaw executor relationships" do
    %{company: company, worker: manager} =
      worker_fixture("openclaw-manager",
        worker_attrs: %{worker_role: "manager", runner_kind: "openclaw_local_manager"}
      )

    %{worker: executor} = worker_fixture("openclaw-executor", company: company)

    assert {:ok, _relationship} =
             AgentRegistry.create_agent_relationship(company.id, %{
               source_worker_id: manager.id,
               target_worker_id: executor.id,
               relationship_kind: "can_delegate_to"
             })

    assert [listed] = AgentRegistry.eligible_execution_workers(company.id, manager.id, %{})
    assert listed.id == executor.id
  end

  defp assignment_fixture(company, profile, worker, title) do
    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: worker.id,
        title: title,
        desired_runner_kind: worker.runner_kind
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: worker.runner_kind
      })

    AgentRegistry.create_worker_assignment(company.id, worker.id, %{work_run_id: run.id})
  end

  defp worker_fixture(key, opts \\ []) do
    company_context = Keyword.get_lazy(opts, :company, fn -> company_fixture(key) end)
    {company, human} = company_and_human(company_context)

    profile_attrs =
      Map.merge(
        %{
          company_id: company.id,
          created_by_human_id: human && human.id,
          name: "#{key} profile",
          agent_kind: "openclaw",
          default_runner_kind: "openclaw_local_executor"
        },
        Keyword.get(opts, :profile_attrs, %{})
      )

    {:ok, profile} = AgentRegistry.create_agent_profile(profile_attrs)

    worker_attrs =
      Map.merge(
        %{
          agent_profile_id: profile.id,
          name: "#{key} worker",
          worker_role: "executor",
          runner_kind: "openclaw_local_executor"
        },
        Keyword.get(opts, :worker_attrs, %{})
      )

    {:ok, worker} = AgentRegistry.register_openclaw_worker(company.id, worker_attrs, %{})

    %{company: company, human: human, profile: profile, worker: worker}
  end

  defp company_fixture(key) do
    human = insert_human!(key)
    company = insert_company!(human, key)

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        created_by_human_id: human.id,
        name: "#{key} base profile",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_executor"
      })

    %{human: human, company: company, profile: profile}
  end

  defp company_and_human(%{company: company} = context), do: {company, Map.get(context, :human)}
  defp company_and_human(%PlatformPhx.AgentPlatform.Company{} = company), do: {company, nil}

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-agent-registry-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, key) do
    slug = "agent-registry-#{key}-#{System.unique_integer([:positive])}"

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
