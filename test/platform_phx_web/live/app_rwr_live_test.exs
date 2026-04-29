defmodule PlatformPhxWeb.AppRwrLiveTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeCheckpointJob
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeRestoreJob
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  @wallet "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  test "work, run, runtimes, and agents pages render seeded company work", %{conn: conn} do
    %{
      human: human,
      runtime: runtime,
      hosted_runtime: hosted_runtime,
      run: run,
      child_run: child_run
    } =
      rwr_fixture()

    conn = init_test_session(conn, %{current_human_id: human.id})

    {:ok, work_view, work_html} = live(conn, "/app/work")
    assert work_html =~ "Draft operator notes"
    assert work_html =~ "Assigned worker"
    assert work_html =~ "Runs with"
    assert work_html =~ "OpenClaw local worker"
    assert work_html =~ "Completed"
    assert work_html =~ "Proof"
    assert work_html =~ "1 proof, 1 approval"
    refute has_element?(work_view, "button[disabled]", "Publish")

    work_view
    |> form("#create-work-form", %{
      "title" => "Prepare launch checklist",
      "body" => "List the next operator actions.",
      "worker_id" => runtime_worker_id(runtime.id)
    })
    |> render_submit()

    assert render(work_view) =~ "Work added."
    assert render(work_view) =~ "Prepare launch checklist"
    created_item = work_item_by_title(human.id, run.company_id, "Prepare launch checklist")

    work_view
    |> element(
      "button[phx-click='start_run'][phx-value-item_id='#{created_item.id}']",
      "Start run"
    )
    |> render_click()

    assert render(work_view) =~ "Run started."

    {:ok, run_view, run_html} = live(conn, "/app/runs/#{run.id}")
    assert run_html =~ "Run family"
    assert run_html =~ "Full run tree"
    assert run_html =~ "Root run #{run.id}"
    assert run_html =~ "Child run"
    assert run_html =~ "Child notes were prepared."
    assert run_html =~ "Event timeline"
    assert run_html =~ "Artifacts"
    assert run_html =~ "Approvals"
    assert run_html =~ "Assigned worker"
    assert run_html =~ "Publish proof"
    assert run_html =~ "Pending review"
    refute run_html =~ "keep this private"

    run_view
    |> element("button[phx-click='resolve_approval'][phx-value-decision='approved']", "Approve")
    |> render_click()

    assert render(run_view) =~ "Review approved."
    assert render(run_view) =~ "Approved review"

    run_view
    |> element("button[phx-click='publish_artifact']", "Publish proof")
    |> render_click()

    assert render(run_view) =~ "Proof published."
    assert render(run_view) =~ "Published"

    {:ok, work_view, _work_html} = live(conn, "/app/work")

    work_view
    |> element("button[phx-click='publish_run_artifacts'][phx-value-run_id='#{child_run.id}']")
    |> render_click()

    assert render(work_view) =~ "Proof published."

    assert Enum.any?(
             WorkRuns.list_artifacts(run.company_id, run.id),
             &(&1.visibility == "public")
           )

    {:ok, runtimes_view, runtimes_html} = live(conn, "/app/runtimes")
    assert runtimes_html =~ "Runtimes"
    assert runtimes_html =~ "Operator machine"
    assert runtimes_html =~ "Checkpoints"
    assert runtimes_html =~ "Runs with"
    assert runtimes_html =~ "Capacity"
    assert runtimes_html =~ "512 MB"
    assert runtimes_html =~ "Upgrade capacity"
    assert runtimes_html =~ "Latest note: Worker ready"
    assert runtimes_html =~ "Restore pending"
    assert runtimes_html =~ "Save checkpoint"
    assert has_element?(runtimes_view, "button[phx-click='restore_runtime']", "Restore")

    runtimes_view
    |> element("button[phx-click='pause_runtime'][phx-value-runtime_id='#{runtime.id}']")
    |> render_click()

    assert render(runtimes_view) =~ "Runtime paused."
    assert render(runtimes_view) =~ "Resume"

    runtimes_view
    |> element("button[phx-click='checkpoint_runtime'][phx-value-runtime_id='#{runtime.id}']")
    |> render_click()

    assert render(runtimes_view) =~ "Checkpoint saved."

    runtimes_view
    |> element(
      "button[phx-click='checkpoint_runtime'][phx-value-runtime_id='#{hosted_runtime.id}']"
    )
    |> render_click()

    assert render(runtimes_view) =~ "Checkpoint requested."

    assert_enqueued(
      worker: RuntimeCheckpointJob,
      args: %{runtime_checkpoint_id: pending_checkpoint_id(hosted_runtime.id)}
    )

    runtimes_view
    |> element("button[phx-click='restore_runtime'][phx-value-runtime_id='#{hosted_runtime.id}']")
    |> render_click()

    assert render(runtimes_view) =~ "Restore requested."

    assert_enqueued(
      worker: RuntimeRestoreJob,
      args: %{runtime_checkpoint_id: hosted_runtime.ready_checkpoint_id}
    )

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
    platform_agent = insert_agent!(human, company, "browser-rwr")

    {:ok, runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "Local OpenClaw",
        runner_kind: "openclaw_local_executor",
        execution_surface: "local_bridge",
        observed_memory_mb: 512,
        observed_storage_bytes: 1_500_000_000,
        observed_capacity_at: DateTime.utc_now() |> DateTime.truncate(:second),
        rate_limit_upgrade_url: "https://billing.example.test/upgrade"
      })

    {:ok, hosted_runtime} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        platform_agent_id: platform_agent.id,
        name: "Hosted Codex",
        runner_kind: "codex_exec",
        execution_surface: "hosted_sprite",
        billing_mode: "platform_hosted",
        provider_runtime_id: "sprite-browser-rwr"
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

    {:ok, child_run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        parent_run_id: run.id,
        root_run_id: run.id,
        delegated_by_run_id: run.id,
        worker_id: worker.id,
        runtime_profile_id: runtime.id,
        runner_kind: "openclaw_local_executor",
        status: "completed",
        summary: "Child notes were prepared.",
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
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

    {:ok, _child_artifact} =
      WorkRuns.create_artifact(%{
        company_id: company.id,
        work_item_id: item.id,
        run_id: child_run.id,
        kind: "proof_packet",
        title: "Child run proof"
      })

    {:ok, _child_approval} =
      WorkRuns.create_approval_request(%{
        company_id: company.id,
        work_run_id: child_run.id,
        kind: "protected_action",
        requested_by_actor_kind: "worker",
        risk_summary: "Child operator review requested."
      })

    {:ok, _service} =
      RuntimeRegistry.create_runtime_service(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        name: "Operator machine",
        service_kind: "bridge",
        status: "active",
        status_observed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        log_cursor: "log-1",
        last_log_excerpt: "Worker ready"
      })

    {:ok, _checkpoint} =
      RuntimeRegistry.create_runtime_checkpoint(%{
        company_id: company.id,
        runtime_profile_id: runtime.id,
        work_run_id: run.id,
        checkpoint_ref: "notes-ready",
        status: "ready",
        captured_at: DateTime.utc_now() |> DateTime.truncate(:second),
        restore_status: "pending"
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

    {:ok, hosted_checkpoint} =
      RuntimeRegistry.create_runtime_checkpoint(%{
        company_id: company.id,
        runtime_profile_id: hosted_runtime.id,
        checkpoint_ref: "hosted-ready",
        status: "ready",
        protected: true,
        captured_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %{
      human: human,
      company: company,
      runtime: runtime,
      hosted_runtime: Map.put(hosted_runtime, :ready_checkpoint_id, hosted_checkpoint.id),
      run: run,
      child_run: child_run
    }
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
      PlatformPhx.AgentPlatform.Companies.create_company(human, %{
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{slug} summary"
      })

    company
  end

  defp insert_agent!(human, company, key) do
    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      company_id: company.id,
      template_key: "start",
      name: "#{key} Hosted Agent",
      slug: "#{key}-agent-#{System.unique_integer([:positive])}",
      claimed_label: "#{key}-agent",
      basename_fqdn: "#{key}.agent.base.eth",
      ens_fqdn: "#{key}.regent.eth",
      status: "published",
      public_summary: "#{key} hosted agent",
      sprite_name: "#{key}-sprite",
      sprite_service_name: "codex-workspace",
      runtime_status: "ready",
      desired_runtime_state: "active",
      observed_runtime_state: "active"
    })
    |> Repo.insert!()
  end

  defp pending_checkpoint_id(runtime_profile_id) do
    RuntimeRegistry.list_runtime_checkpoints(
      Repo.get!(RuntimeRegistry.RuntimeProfile, runtime_profile_id).company_id
    )
    |> Enum.find(&(&1.runtime_profile_id == runtime_profile_id and &1.status == "pending"))
    |> Map.fetch!(:id)
  end

  defp runtime_worker_id(runtime_profile_id) do
    PlatformPhx.AgentRegistry.AgentWorker
    |> Repo.get_by!(runtime_profile_id: runtime_profile_id)
    |> Map.fetch!(:id)
  end

  defp work_item_by_title(human_id, company_id, title) do
    human_id
    |> Work.list_items_for_owned_company(company_id)
    |> Enum.find(&(&1.title == title))
  end
end
