defmodule PlatformPhx.RunEventsTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  test "append assigns sequence 1, then 2" do
    %{company: company, run: run} = run_fixture()

    assert {:ok, first} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               kind: "run.started"
             })

    assert {:ok, second} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               kind: "run.updated"
             })

    assert first.sequence == 1
    assert second.sequence == 2
  end

  test "append accepts current event fields from JSON-shaped params" do
    %{company: company, run: run} = run_fixture()

    assert {:ok, event} =
             RunEvents.append_event(%{
               "company_id" => company.id,
               "run_id" => run.id,
               "kind" => "run.message",
               "payload" => %{"api_key" => "sk-secret", "safe" => "ok"}
             })

    assert event.sequence == 1
    assert event.payload == %{"api_key" => "[redacted]", "safe" => "ok"}
  end

  test "explicit correct next sequence succeeds and wrong next sequence returns an error" do
    %{company: company, run: run} = run_fixture()

    assert {:ok, first} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               sequence: 1,
               kind: "run.started"
             })

    assert first.sequence == 1

    assert {:error, {:sequence_mismatch, %{expected: 2, received: 3}}} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               sequence: 3,
               kind: "run.updated"
             })
  end

  test "batch append is all-or-nothing when a later event has a bad sequence" do
    %{company: company, run: run} = run_fixture()
    :ok = RunEvents.subscribe(run.id)
    on_exit(fn -> RunEvents.unsubscribe(run.id) end)

    assert {:error, {:sequence_mismatch, %{expected: 2, received: 3}}} =
             RunEvents.append_events([
               %{
                 company_id: company.id,
                 run_id: run.id,
                 kind: "run.started"
               },
               %{
                 company_id: company.id,
                 run_id: run.id,
                 sequence: 3,
                 kind: "run.updated"
               }
             ])

    assert [] == RunEvents.list_events(company.id, run.id)
    refute_receive {:rwr_run_event, _event}, 100
  end

  test "concurrent append attempts produce a complete non-duplicated sequence set", %{
    sandbox_owner: sandbox_owner
  } do
    %{company: company, run: run} = run_fixture()

    results =
      1..8
      |> Task.async_stream(
        fn index ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, sandbox_owner, self())

          RunEvents.append_event(%{
            company_id: company.id,
            run_id: run.id,
            kind: "run.step",
            payload: %{index: index}
          })
        end,
        max_concurrency: 8,
        ordered: false,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.all?(results, &match?({:ok, _event}, &1))

    sequences =
      company.id
      |> RunEvents.list_events(run.id)
      |> Enum.map(& &1.sequence)

    assert sequences == Enum.to_list(1..8)
  end

  test "idempotency key returns the original event and does not broadcast twice" do
    %{company: company, run: run} = run_fixture()
    :ok = RunEvents.subscribe(run.id)
    on_exit(fn -> RunEvents.unsubscribe(run.id) end)

    attrs = %{
      company_id: company.id,
      run_id: run.id,
      kind: "run.started",
      idempotency_key: "run-started",
      payload: %{attempt: 1}
    }

    assert {:ok, first} = RunEvents.append_event(attrs)
    assert_receive {:rwr_run_event, broadcast_event}
    assert broadcast_event.id == first.id

    assert {:ok, second} = RunEvents.append_event(Map.put(attrs, :payload, %{attempt: 2}))
    refute_receive {:rwr_run_event, _event}, 100

    assert second.id == first.id
    assert second.payload == %{"attempt" => 1}

    assert [stored_event] = RunEvents.list_events(company.id, run.id)
    assert stored_event.id == first.id
  end

  test "list and replay order is stable" do
    %{company: company, run: run} = run_fixture()

    assert {:ok, third} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               sequence: 1,
               kind: "run.third",
               occurred_at: ~U[2026-01-01 00:00:03Z]
             })

    assert {:ok, first} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               sequence: 2,
               kind: "run.first",
               occurred_at: ~U[2026-01-01 00:00:01Z]
             })

    assert {:ok, second} =
             RunEvents.append_event(%{
               company_id: company.id,
               run_id: run.id,
               sequence: 3,
               kind: "run.second",
               occurred_at: ~U[2026-01-01 00:00:02Z]
             })

    assert RunEvents.list_events(company.id, run.id) == [third, first, second]
    assert RunEvents.replay_events(company.id, run.id) == [third, first, second]
  end

  defp run_fixture do
    human = insert_human!(System.unique_integer([:positive]))
    company = insert_company!(human, "run-events-#{System.unique_integer([:positive])}")

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

    %{company: company, run: run}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-run-events-#{key}",
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
