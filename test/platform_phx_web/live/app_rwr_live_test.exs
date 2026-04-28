defmodule PlatformPhxWeb.AppRwrLiveTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  @wallet "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  test "work, run, runtimes, and agents pages render seeded company work", %{conn: conn} do
    %{human: human, run: run} = rwr_fixture()
    conn = init_test_session(conn, %{current_human_id: human.id})

    {:ok, _view, work_html} = live(conn, "/app/work")
    assert work_html =~ "Draft operator notes"
    assert work_html =~ "Assigned worker"
    assert work_html =~ "Runs with"
    assert work_html =~ "OpenClaw local worker"
    assert work_html =~ "Completed"

    {:ok, _view, run_html} = live(conn, "/app/runs/#{run.id}")
    assert run_html =~ "Run path"
    assert run_html =~ "Event timeline"
    assert run_html =~ "Artifacts"
    assert run_html =~ "Approvals"
    assert run_html =~ "Assigned worker"
    refute run_html =~ "keep this private"

    {:ok, _view, runtimes_html} = live(conn, "/app/runtimes")
    assert runtimes_html =~ "Runtimes"
    assert runtimes_html =~ "Operator machine"
    assert runtimes_html =~ "Checkpoints"
    assert runtimes_html =~ "Runs with"

    {:ok, _view, agents_html} = live(conn, "/app/agents")
    assert agents_html =~ "Connected agents and workers"
    assert agents_html =~ "Execution pool"
    assert agents_html =~ "Last check-in"
    assert agents_html =~ "Assigned worker"

    for html <- [work_html, run_html, runtimes_html, agents_html] do
      refute html =~ "runner_kind"
      refute html =~ "local_bridge"
      refute html =~ "API wiring"
      refute html =~ "fallback"
      refute html =~ "hard cutover"
      refute html =~ "LiveView"
      refute html =~ "heartbeat"
    end
  end

  test "empty states render without seeded work", %{conn: conn} do
    human = insert_human!("empty")
    _company = insert_company!(human, "empty-rwr")
    conn = init_test_session(conn, %{current_human_id: human.id})

    {:ok, _view, work_html} = live(conn, "/app/work")
    assert work_html =~ "No work items yet."

    {:ok, _view, runtimes_html} = live(conn, "/app/runtimes")
    assert runtimes_html =~ "No runtimes connected."

    {:ok, _view, agents_html} = live(conn, "/app/agents")
    assert agents_html =~ "No agents connected."

    {:ok, _view, run_html} = live(conn, "/app/runs/999999")
    assert run_html =~ "Run not found."
  end

  defp rwr_fixture do
    human = insert_human!(System.unique_integer([:positive]))
    company = insert_company!(human, "browser-rwr-#{System.unique_integer([:positive])}")

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
        default_runner_kind: "openclaw_local_executor",
        public_description: "Handles local company work."
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
        runner_kind: "openclaw_local_executor",
        status: "active",
        last_heartbeat_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile.id,
        assigned_worker_id: worker.id,
        title: "Draft operator notes",
        body: "Prepare a short update for the operator.",
        status: "running",
        desired_runner_kind: "openclaw_local_executor"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runtime_profile_id: runtime.id,
        runner_kind: "openclaw_local_executor",
        status: "completed",
        summary: "Notes were prepared."
      })

    {:ok, _event} =
      RunEvents.append_event(%{
        company_id: company.id,
        run_id: run.id,
        kind: "run.completed",
        sensitivity: "sensitive",
        payload: %{"instructions" => "keep this private"}
      })

    {:ok, _artifact} =
      WorkRuns.create_artifact(%{
        company_id: company.id,
        work_item_id: item.id,
        run_id: run.id,
        kind: "proof_packet",
        title: "Run proof"
      })

    {:ok, _approval} =
      WorkRuns.create_approval_request(%{
        company_id: company.id,
        work_run_id: run.id,
        kind: "protected_action",
        requested_by_actor_kind: "worker",
        risk_summary: "Operator review requested."
      })

    {:ok, _service} =
      RuntimeRegistry.create_runtime_service(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        name: "Operator machine",
        service_kind: "bridge",
        status: "active"
      })

    {:ok, _checkpoint} =
      RuntimeRegistry.create_runtime_checkpoint(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        work_run_id: run.id,
        checkpoint_ref: "notes-ready",
        status: "ready"
      })

    {:ok, _usage} =
      RuntimeRegistry.create_usage_snapshot(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        snapshot_at: DateTime.utc_now() |> DateTime.truncate(:second),
        provider: "openclaw_local",
        compute_state: "active",
        active_seconds: 180
      })

    {:ok, _relationship} =
      AgentRegistry.create_relationship(%{
        company_id: company.id,
        source_agent_profile_id: profile.id,
        target_worker_id: worker.id,
        relationship_kind: "preferred_executor"
      })

    %{human: human, company: company, run: run}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-live-rwr-#{key}",
      wallet_address: @wallet,
      wallet_addresses: [@wallet]
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
end
