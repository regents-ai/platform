defmodule PlatformPhxWeb.Api.RegentWorkRuntimeControllerTest do
  use PlatformPhxWeb.ConnCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentProfile
  alias PlatformPhx.AgentRegistry.WorkerAssignment
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns

  @wallet "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @other_wallet "0x0000000000000000000000000000000000000002"

  setup do
    previous_client = Application.get_env(:platform_phx, :siwa_client)
    Application.put_env(:platform_phx, :siwa_client, PlatformPhx.TestSiwaClient)

    on_exit(fn ->
      Application.put_env(:platform_phx, :siwa_client, previous_client)
    end)

    :ok
  end

  test "session routes create work and start a run for an owned company", %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-work")

    create_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/work-items", %{
        "company_id" => to_string(company.id),
        "title" => "Review operator notes",
        "description" => "Summarize the current operator notes.",
        "priority" => "urgent"
      })
      |> json_response(201)

    assert create_response["ok"] == true
    work_item_id = create_response["work_item"]["id"]
    assert create_response["work_item"]["description"] == "Summarize the current operator notes."

    list_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/companies/#{company.id}/rwr/work-items")
      |> json_response(200)

    assert [%{"id" => ^work_item_id}] = list_response["work_items"]

    run_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{work_item_id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(work_item_id),
          "runner_kind" => "fake",
          "instructions" => "Use the fake runner."
        }
      )
      |> json_response(201)

    assert run_response["ok"] == true
    assert run_response["run"]["runner_kind"] == "fake"
    assert run_response["run"]["status"] == "queued"
  end

  test "session routes create, show, checkpoint, restore, pause, resume, and inspect runtime lifecycle",
       %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-runtime-lifecycle")

    create_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runtimes", %{
        "company_id" => to_string(company.id),
        "name" => "Local OpenClaw",
        "runner_kind" => "openclaw_local_executor",
        "execution_surface" => "local_bridge",
        "billing_mode" => "user_local",
        "metadata" => %{"purpose" => "tests"}
      })
      |> json_response(201)

    runtime_id = create_response["runtime"]["id"]
    assert create_response["runtime"]["company_id"] == company.id
    assert create_response["runtime"]["status"] == "active"
    assert create_response["runtime"]["metadata"] == %{"purpose" => "tests"}

    show_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}")
      |> json_response(200)

    assert show_response["runtime"]["id"] == runtime_id

    {:ok, service} =
      RuntimeRegistry.create_runtime_service(%{
        company_id: company.id,
        runtime_profile_id: runtime_id,
        name: "workspace",
        service_kind: "http",
        endpoint_url: "https://workspace.example"
      })

    services_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/services")
      |> json_response(200)

    assert [%{"id" => service_id, "name" => "workspace"}] = services_response["services"]
    assert service_id == service.id

    health_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/health")
      |> json_response(200)

    assert health_response["health"] == %{
             "available" => true,
             "metering_status" => "unmetered",
             "status" => "active"
           }

    checkpoint_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/checkpoint",
        %{
          "company_id" => to_string(company.id),
          "runtime_id" => to_string(runtime_id),
          "checkpoint_ref" => "local-checkpoint-1"
        }
      )
      |> json_response(201)

    checkpoint_id = checkpoint_response["checkpoint"]["id"]
    assert checkpoint_response["checkpoint"]["protected"] == false
    assert checkpoint_response["checkpoint"]["checkpoint_ref"] == "local-checkpoint-1"

    restore_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/restore", %{
        "company_id" => to_string(company.id),
        "runtime_id" => to_string(runtime_id),
        "checkpoint_id" => to_string(checkpoint_id)
      })
      |> json_response(200)

    assert restore_response["restore"] == %{"status" => "accepted"}
    assert restore_response["checkpoint"]["id"] == checkpoint_id

    pause_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/pause", %{})
      |> json_response(200)

    assert pause_response["runtime"]["status"] == "paused"

    resume_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/runtimes/#{runtime_id}/resume",
        %{}
      )
      |> json_response(200)

    assert resume_response["runtime"]["status"] == "active"
  end

  test "signed worker routes connect OpenClaw locally and claim assignments", %{conn: conn} do
    %{company: company} = company_fixture("controller-worker")

    register_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/workers", %{
        "company_id" => to_string(company.id),
        "agent_kind" => "openclaw",
        "worker_role" => "executor",
        "execution_surface" => "local_bridge",
        "runner_kind" => "openclaw_local_executor",
        "billing_mode" => "user_local",
        "trust_scope" => "local_user_controlled",
        "reported_usage_policy" => "self_reported",
        "display_name" => "Local OpenClaw"
      })
      |> json_response(201)

    worker_id = register_response["worker"]["id"]
    profile_id = register_response["agent_profile"]["id"]
    assert register_response["worker"]["execution_surface"] == "local_bridge"
    assert register_response["worker"]["billing_mode"] == "user_local"
    assert register_response["worker"]["trust_scope"] == "local_user_controlled"
    assert register_response["worker"]["reported_usage_policy"] == "self_reported"

    heartbeat_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/workers/#{worker_id}/heartbeat", %{
        "status" => "active"
      })
      |> json_response(200)

    assert heartbeat_response["worker"]["status"] == "active"

    worker = AgentRegistry.get_worker(company.id, worker_id)

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: profile_id,
        assigned_worker_id: worker_id,
        title: "Local assignment",
        desired_runner_kind: "openclaw_local_executor"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: "openclaw_local_executor"
      })

    public_artifact_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/artifacts", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "artifact_type" => "proof_packet",
        "visibility" => "public",
        "body" => "Local proof"
      })
      |> json_response(403)

    assert public_artifact_response["statusMessage"] ==
             "Publishing this artifact requires an explicit action"

    event_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/events", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "kind" => "worker.status",
        "payload" => %{"message" => "claimed locally"}
      })
      |> json_response(201)

    assert event_response["event"]["kind"] == "worker.status"
    assert event_response["event"]["run_id"] == run.id

    artifact_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/artifacts", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "artifact_type" => "proof_packet",
        "visibility" => "operator",
        "body" => "Local proof"
      })
      |> json_response(201)

    assert artifact_response["artifact"]["visibility"] == "operator"

    {:ok, assignment} =
      AgentRegistry.create_worker_assignment(company.id, worker.id, %{work_run_id: run.id})

    assignments_response =
      conn
      |> put_siwa_headers()
      |> get("/api/agent-platform/companies/#{company.id}/rwr/workers/#{worker_id}/assignments")
      |> json_response(200)

    assert [%{"id" => assignment_id}] = assignments_response["assignments"]
    assert assignment_id == assignment.id

    claim_response =
      conn
      |> put_siwa_headers()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/assignments/#{assignment.id}/claim",
        %{}
      )
      |> json_response(200)

    assert claim_response["assignment"]["status"] == "claimed"
  end

  test "signed worker routes require the signer wallet to match the company owner", %{conn: conn} do
    %{company: company} =
      company_fixture("controller-worker-forbidden",
        wallet: "0x0000000000000000000000000000000000000001"
      )

    response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/workers", %{
        "company_id" => to_string(company.id),
        "agent_kind" => "openclaw",
        "worker_role" => "executor",
        "execution_surface" => "local_bridge",
        "runner_kind" => "openclaw_local_executor",
        "billing_mode" => "user_local",
        "trust_scope" => "local_user_controlled",
        "reported_usage_policy" => "self_reported",
        "display_name" => "Unlinked OpenClaw"
      })
      |> json_response(403)

    assert response["statusMessage"] == "Signed agent is not connected to this company"
  end

  test "signed worker routes require the signer to match the registered worker", %{conn: conn} do
    %{company: company} =
      company_fixture("controller-worker-bound",
        wallet_addresses: [@wallet, @other_wallet]
      )

    register_response =
      conn
      |> put_siwa_headers("platform-receipt-other")
      |> post("/api/agent-platform/companies/#{company.id}/rwr/workers", %{
        "company_id" => to_string(company.id),
        "agent_kind" => "openclaw",
        "worker_role" => "executor",
        "execution_surface" => "local_bridge",
        "runner_kind" => "openclaw_local_executor",
        "billing_mode" => "user_local",
        "trust_scope" => "local_user_controlled",
        "reported_usage_policy" => "self_reported",
        "display_name" => "Other OpenClaw"
      })
      |> json_response(201)

    response =
      conn
      |> put_siwa_headers()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/workers/#{register_response["worker"]["id"]}/heartbeat",
        %{"status" => "active"}
      )
      |> json_response(403)

    assert response["statusMessage"] == "Signed agent is not assigned to this worker"
  end

  test "signed run routes require the signer to match the run worker", %{conn: conn} do
    %{company: company} =
      company_fixture("controller-run-bound", wallet_addresses: [@wallet, @other_wallet])

    %{worker: worker} =
      worker_fixture(company, "other-worker", "platform-receipt-other",
        worker_role: "manager",
        runner_kind: "openclaw_local_manager"
      )

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: worker.agent_profile_id,
        assigned_worker_id: worker.id,
        title: "Run-bound assignment",
        desired_runner_kind: "openclaw_local_manager"
      })

    {:ok, run} =
      WorkRuns.create_run(%{
        company_id: company.id,
        work_item_id: item.id,
        worker_id: worker.id,
        runner_kind: "openclaw_local_manager"
      })

    event_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/events", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "kind" => "worker.status"
      })
      |> json_response(403)

    assert event_response["statusMessage"] == "Signed agent is not assigned to this worker"

    artifact_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/artifacts", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "artifact_type" => "proof_packet",
        "visibility" => "operator",
        "body" => "Wrong signer proof"
      })
      |> json_response(403)

    assert artifact_response["statusMessage"] == "Signed agent is not assigned to this worker"

    delegation_response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/runs/#{run.id}/delegations", %{
        "company_id" => to_string(company.id),
        "run_id" => to_string(run.id),
        "requested_runner_kind" => "openclaw_local_executor",
        "strategy" => "single_executor",
        "tasks" => [%{"title" => "Follow-up", "instructions" => "Continue locally"}]
      })
      |> json_response(403)

    assert delegation_response["statusMessage"] == "Signed agent is not assigned to this worker"
  end

  test "relationship creation requires the body source to match the route source", %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-relationship-source")

    {:ok, source_profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "Source manager",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_manager"
      })

    {:ok, other_source_profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "Other manager",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_manager"
      })

    {:ok, target_profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "Target executor",
        agent_kind: "openclaw",
        default_runner_kind: "openclaw_local_executor"
      })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/agents/#{source_profile.id}/relationships",
        %{
          "company_id" => to_string(company.id),
          "source_agent_profile_id" => other_source_profile.id,
          "target_agent_profile_id" => target_profile.id,
          "relationship_kind" => "can_delegate_to"
        }
      )
      |> json_response(400)

    assert response["statusMessage"] == "Relationship source does not match the route"
  end

  test "run start requires the body work item id to match the route", %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-run-start-match")

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        title: "Route-bound work",
        desired_runner_kind: "fake"
      })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{item.id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(item.id + 1),
          "runner_kind" => "fake"
        }
      )
      |> json_response(400)

    assert response["statusMessage"] == "Work item id does not match the route"
  end

  test "run start keeps local workers on local work", %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-run-worker-shape")
    %{worker: worker} = worker_fixture(company, "local-openclaw-runner", "platform-receipt", [])

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: worker.agent_profile_id,
        assigned_worker_id: worker.id,
        title: "Shape-bound work",
        desired_runner_kind: "openclaw_local_executor"
      })

    local_without_worker =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{item.id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(item.id),
          "runner_kind" => "openclaw_local_executor"
        }
      )
      |> json_response(400)

    assert local_without_worker["statusMessage"] == "Local work needs an assigned local worker"

    hosted_with_local_worker =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{item.id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(item.id),
          "runner_kind" => "codex_exec",
          "worker_id" => to_string(worker.id)
        }
      )
      |> json_response(400)

    assert hosted_with_local_worker["statusMessage"] == "This worker cannot run the selected work"
  end

  test "run start rejects work that has no current start path", %{conn: conn} do
    %{human: human, company: company} = company_fixture("controller-run-startable")
    %{worker: worker} = worker_fixture(company, "custom-local-runner", "platform-receipt", [])

    {:ok, item} =
      Work.create_item(%{
        company_id: company.id,
        assigned_agent_profile_id: worker.agent_profile_id,
        assigned_worker_id: worker.id,
        title: "Startable work",
        desired_runner_kind: "openclaw_local_executor"
      })

    unsupported_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{item.id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(item.id),
          "runner_kind" => "hermes_hosted_manager"
        }
      )
      |> json_response(400)

    assert unsupported_response["statusMessage"] == "Selected work needs an assigned worker"

    assert WorkRuns.list_runs_for_work_items([item.id]) == []

    local_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post(
        "/api/agent-platform/companies/#{company.id}/rwr/work-items/#{item.id}/runs",
        %{
          "company_id" => to_string(company.id),
          "work_item_id" => to_string(item.id),
          "runner_kind" => "openclaw_local_executor",
          "worker_id" => to_string(worker.id)
        }
      )
      |> json_response(201)

    run_id = local_response["run"]["id"]

    assert [%WorkerAssignment{work_run_id: work_run_id, worker_id: worker_id}] =
             AgentRegistry.list_worker_assignments(company.id, worker.id)

    assert work_run_id == run_id
    assert worker_id == worker.id
  end

  test "failed worker registration does not leave a profile behind", %{conn: conn} do
    %{company: company} = company_fixture("controller-worker-transaction")
    profile_count = Repo.aggregate(AgentProfile, :count, :id)

    response =
      conn
      |> put_siwa_headers()
      |> post("/api/agent-platform/companies/#{company.id}/rwr/workers", %{
        "company_id" => to_string(company.id),
        "agent_kind" => "openclaw",
        "worker_role" => "executor",
        "execution_surface" => "hosted_sprite",
        "runner_kind" => "openclaw_local_executor",
        "billing_mode" => "user_local",
        "trust_scope" => "local_user_controlled",
        "reported_usage_policy" => "self_reported",
        "display_name" => "Hosted OpenClaw"
      })
      |> json_response(400)

    assert response["statusMessage"] == "Invalid RWR request"
    assert Repo.aggregate(AgentProfile, :count, :id) == profile_count
  end

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end

  defp put_siwa_headers(conn, receipt \\ "platform-receipt"),
    do: put_req_header(conn, "x-siwa-receipt", receipt)

  defp worker_fixture(company, key, receipt, opts) do
    worker_role = Keyword.get(opts, :worker_role, "executor")
    runner_kind = Keyword.get(opts, :runner_kind, "openclaw_local_executor")

    {:ok, profile} =
      AgentRegistry.create_agent_profile(%{
        company_id: company.id,
        name: "#{key} profile",
        agent_kind: "openclaw",
        default_runner_kind: runner_kind
      })

    subject = siwa_subject(receipt)

    {:ok, worker} =
      AgentRegistry.register_worker(
        company.id,
        %{
          agent_profile_id: profile.id,
          name: "#{key} worker",
          agent_kind: "openclaw",
          worker_role: worker_role,
          execution_surface: "local_bridge",
          runner_kind: runner_kind,
          billing_mode: "user_local",
          trust_scope: "local_user_controlled",
          reported_usage_policy: "self_reported",
          siwa_subject: subject
        },
        subject
      )

    %{profile: profile, worker: worker}
  end

  defp siwa_subject("platform-receipt-other") do
    %{
      "wallet_address" => @other_wallet,
      "chain_id" => 84_532,
      "registry_address" => "0x3333333333333333333333333333333333333333",
      "token_id" => "78"
    }
  end

  defp siwa_subject(_receipt) do
    %{
      "wallet_address" => @wallet,
      "chain_id" => 84_532,
      "registry_address" => "0x3333333333333333333333333333333333333333",
      "token_id" => "77"
    }
  end

  defp company_fixture(key, opts \\ []) do
    human = insert_human!(key, opts)
    slug = "#{key}-#{System.unique_integer([:positive])}"

    {:ok, company} =
      AgentPlatform.create_company(human, %{
        name: "#{key} Regent",
        slug: slug,
        claimed_label: slug,
        status: "forming",
        public_summary: "#{key} summary"
      })

    %{human: human, company: company}
  end

  defp insert_human!(key, opts) do
    wallet = Keyword.get(opts, :wallet, @wallet)
    wallet_addresses = Keyword.get(opts, :wallet_addresses, [wallet])

    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-rwr-controller-#{key}",
      wallet_address: wallet,
      wallet_addresses: wallet_addresses
    })
    |> Repo.insert!()
  end
end
