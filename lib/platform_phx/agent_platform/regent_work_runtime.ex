defmodule PlatformPhx.AgentPlatform.RegentWorkRuntime do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.ApprovalRequest
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun

  @async_runner_kinds ["fake", "codex_exec", "codex_app_server"]
  @local_runner_kinds [
    "hermes_local_manager",
    "openclaw_local_manager",
    "openclaw_local_executor",
    "openclaw_code_agent_local"
  ]
  @worker_claim_fields ~w(wallet_address chain_id registry_address token_id)
  @runner_worker_shapes %{
    "hermes_local_manager" => %{
      agent_kind: "hermes",
      execution_surface: "local_bridge",
      runner_kinds: ["hermes_local_manager"]
    },
    "hermes_hosted_manager" => %{
      agent_kind: "hermes",
      execution_surface: "hosted_sprite",
      runner_kinds: ["hermes_hosted_manager"]
    },
    "openclaw_local_manager" => %{
      agent_kind: "openclaw",
      execution_surface: "local_bridge",
      runner_kinds: ["openclaw_local_manager"]
    },
    "openclaw_local_executor" => %{
      agent_kind: "openclaw",
      execution_surface: "local_bridge",
      runner_kinds: ["openclaw_local_executor", "openclaw_code_agent_local"]
    },
    "openclaw_code_agent_local" => %{
      agent_kind: "openclaw",
      execution_surface: "local_bridge",
      runner_kinds: ["openclaw_local_executor", "openclaw_code_agent_local"]
    },
    "codex_exec" => %{
      agent_kind: "codex",
      execution_surface: "hosted_sprite",
      runner_kinds: ["codex_exec", "codex_app_server"]
    },
    "codex_app_server" => %{
      agent_kind: "codex",
      execution_surface: "hosted_sprite",
      runner_kinds: ["codex_exec", "codex_app_server"]
    }
  }

  def list_owned_work_items(human_id, company_id),
    do: Work.list_items_for_owned_company(human_id, company_id)

  def create_work_item(attrs), do: Work.create_item(attrs)

  def get_owned_work_item(human_id, company_id, work_item_id) do
    human_id
    |> Work.list_items_for_owned_company(company_id)
    |> Enum.find(&(to_string(&1.id) == to_string(work_item_id)))
  end

  def create_run(attrs), do: WorkRuns.create_run(attrs)

  def get_owned_run(human_id, company_id, run_id) do
    case WorkRuns.get_owned_run(human_id, parse_id(run_id)) do
      %WorkRun{company_id: ^company_id} = run -> run
      _run -> nil
    end
  end

  def get_run(company_id, run_id), do: WorkRuns.get_run(company_id, run_id)

  def run_tree(%WorkRun{} = run) do
    %{
      run: run,
      children:
        run.id
        |> WorkRuns.list_child_runs()
        |> Enum.map(&run_tree/1)
    }
  end

  def cancel_run(%WorkRun{} = run) do
    WorkRuns.cancel_run(run)
  end

  def retry_run(%WorkRun{} = run) do
    with :ok <- retryable_run(run),
         {:ok, retry} <- WorkRuns.create_run(retry_run_attrs(run)),
         :ok <- after_run_created(run.worker, retry) do
      {:ok, retry}
    end
  end

  def list_run_events(company_id, run_id), do: RunEvents.list_events(company_id, run_id)

  def replay_run_events(company_id, run_id), do: RunEvents.replay_events(company_id, run_id)

  def list_artifacts(company_id, run_id), do: WorkRuns.list_artifacts(company_id, run_id)

  def get_run_artifact(company_id, run_id, artifact_id) do
    company_id
    |> WorkRuns.list_artifacts(run_id)
    |> Enum.find(&(to_string(&1.id) == to_string(artifact_id)))
  end

  def get_company_artifact(company_id, artifact_id) do
    Repo.get_by(WorkArtifact, company_id: company_id, id: parse_id(artifact_id))
  end

  def publish_artifact(%WorkArtifact{} = artifact), do: WorkRuns.publish_artifact(artifact)

  def list_approvals(company_id, run_id), do: WorkRuns.list_approval_requests(company_id, run_id)

  def get_approval(company_id, run_id, approval_id) do
    company_id
    |> WorkRuns.list_approval_requests(run_id)
    |> Enum.find(&(to_string(&1.id) == to_string(approval_id)))
  end

  def resolve_approval(%ApprovalRequest{} = approval, human_id, attrs) do
    WorkRuns.resolve_approval_request(approval, %{
      status: Map.get(attrs, "decision"),
      resolved_by_human_id: human_id,
      resolved_at: now(),
      payload: Map.merge(approval.payload || %{}, Map.get(attrs, "resolution", %{}))
    })
  end

  def append_event_batch(params, company_id, run_id) do
    case Map.get(params, "events") do
      events when is_list(events) and events != [] ->
        events
        |> Enum.map(fn event_params ->
          event_params
          |> Map.put("company_id", company_id)
          |> Map.put("run_id", run_id)
        end)
        |> RunEvents.append_events()

      _events ->
        {:error, {:bad_request, "Event batch is empty"}}
    end
  end

  def list_workers(company_id), do: AgentRegistry.list_workers_with_details(company_id)

  def register_worker_with_profile(company_id, params, claims) do
    AgentRegistry.register_worker_with_profile(company_id, params, claims)
  end

  def get_worker(company_id, worker_id), do: AgentRegistry.get_worker(company_id, worker_id)

  def signed_company(company_id, claims) when is_map(claims) do
    case required_signed_wallet(claims) do
      {:ok, wallet_address} ->
        PlatformPhx.AgentPlatform.Companies.get_company_for_owner_wallet(
          company_id,
          wallet_address
        )

      :error ->
        {:error, {:forbidden, "Signed agent is not connected to this company"}}
    end
  end

  def signed_worker(company_id, worker_id, claims) do
    with {:ok, %Company{} = company} <- signed_company(company_id, claims),
         %AgentWorker{} = worker <- get_worker(company.id, worker_id),
         :ok <- ensure_claims_match_worker(claims, worker) do
      {:ok, company, worker}
    else
      nil -> {:error, {:not_found, "Worker not found"}}
      {:error, _reason} = error -> error
    end
  end

  def signed_assignment_worker(company_id, assignment_id, claims) do
    with {:ok, %Company{} = company} <- signed_company(company_id, claims),
         assignment when not is_nil(assignment) <-
           get_worker_assignment(company.id, assignment_id),
         %AgentWorker{} = worker <- get_worker(company.id, assignment.worker_id),
         :ok <- ensure_claims_match_worker(claims, worker) do
      {:ok, company, worker, assignment}
    else
      nil -> {:error, {:not_found, "Assignment not found"}}
      {:error, _reason} = error -> error
    end
  end

  def signed_run_worker(company_id, run_id, claims) do
    with {:ok, %Company{} = company} <- signed_company(company_id, claims),
         %WorkRun{} = run <- get_run(company.id, run_id),
         {:ok, worker_id} <- run_worker_id(run),
         %AgentWorker{} = worker <- get_worker(company.id, worker_id),
         :ok <- ensure_claims_match_worker(claims, worker) do
      {:ok, company, run, worker}
    else
      nil -> {:error, {:not_found, "Run not found"}}
      {:error, _reason} = error -> error
    end
  end

  def heartbeat_worker(company_id, worker_id, attrs) do
    AgentRegistry.heartbeat_worker(company_id, worker_id, attrs)
  end

  def list_worker_assignments(company_id, worker_id) do
    AgentRegistry.list_worker_assignments(company_id, worker_id)
  end

  def get_worker_assignment(company_id, assignment_id) do
    AgentRegistry.get_worker_assignment(company_id, assignment_id)
  end

  def claim_worker_assignment(company_id, worker_id, assignment_id) do
    AgentRegistry.claim_worker_assignment(company_id, worker_id, assignment_id)
  end

  def release_worker_assignment(company_id, worker_id, assignment_id) do
    AgentRegistry.release_worker_assignment(company_id, worker_id, assignment_id)
  end

  def complete_worker_assignment(company_id, worker_id, assignment_id) do
    AgentRegistry.complete_worker_assignment(company_id, worker_id, assignment_id)
  end

  def list_runtimes(company_id),
    do: RuntimeRegistry.list_runtime_profiles_with_details(company_id)

  def create_runtime(attrs), do: RuntimeRegistry.create_runtime_profile(attrs)

  def get_runtime(company_id, runtime_id) do
    RuntimeRegistry.get_runtime_profile(company_id, parse_id(runtime_id))
  end

  def list_runtime_services(company_id, runtime_id) do
    RuntimeRegistry.list_runtime_services(company_id, runtime_id)
  end

  def get_checkpoint(company_id, runtime_id, checkpoint_id) do
    RuntimeRegistry.get_runtime_checkpoint(company_id, runtime_id, parse_id(checkpoint_id))
  end

  def create_runtime_checkpoint(%RuntimeProfile{} = runtime, attrs) do
    attrs = checkpoint_attrs(runtime, attrs)

    if hosted_sprite_runtime?(runtime) do
      RuntimeRegistry.create_hosted_sprite_checkpoint(runtime, attrs)
    else
      RuntimeRegistry.create_runtime_checkpoint(attrs)
    end
  end

  def request_runtime_restore(%RuntimeProfile{} = runtime, %RuntimeCheckpoint{} = checkpoint) do
    if hosted_sprite_runtime?(runtime) do
      RuntimeRegistry.request_hosted_sprite_restore(runtime, checkpoint)
    else
      {:ok, checkpoint}
    end
  end

  def change_runtime_state(%RuntimeProfile{} = runtime, target_state, human) do
    runtime = Repo.preload(runtime, :platform_agent)

    result =
      case {target_state, runtime.platform_agent} do
        {"paused", %Agent{} = agent} ->
          RuntimeControl.pause(agent,
            actor_type: "human",
            human_user_id: human.id,
            source: "rwr_api"
          )

        {"active", %Agent{} = agent} ->
          RuntimeControl.resume(agent,
            actor_type: "human",
            human_user_id: human.id,
            source: "rwr_api"
          )

        _other ->
          {:ok, nil}
      end

    with {:ok, _agent} <- result do
      RuntimeRegistry.update_runtime_profile_status(runtime, target_state)
    end
  end

  def runtime_health(%RuntimeProfile{} = runtime) do
    if hosted_sprite_runtime?(Repo.preload(runtime, :platform_agent)) do
      case RuntimeRegistry.hosted_runtime_availability(runtime) do
        %{available?: available?, status: status, metering_status: metering_status} ->
          %{available: available?, status: status, metering_status: metering_status}
      end
    else
      %{
        available: runtime.status == "active",
        status: runtime.status,
        metering_status: "unmetered"
      }
    end
  end

  def runtime_health(_runtime),
    do: %{available: false, status: "unavailable", metering_status: "unmetered"}

  def list_relationships(company_id, source_id) do
    AgentRegistry.list_relationships_for_member(company_id, source_id)
  end

  def create_relationship(company_id, source_id, attrs) do
    AgentRegistry.create_agent_relationship(company_id, source_id, attrs)
  end

  def list_execution_pool(company_id, manager_id) do
    AgentRegistry.list_execution_pool(company_id, manager_id)
  end

  def delete_relationship(company_id, relationship_id) do
    AgentRegistry.delete_relationship(company_id, relationship_id)
  end

  def optional_worker(_company_id, nil, runner_kind) when runner_kind in @local_runner_kinds,
    do: {:error, {:bad_request, "Local work needs an assigned local worker"}}

  def optional_worker(_company_id, "", runner_kind) when runner_kind in @local_runner_kinds,
    do: {:error, {:bad_request, "Local work needs an assigned local worker"}}

  def optional_worker(_company_id, nil, _runner_kind), do: {:ok, nil}
  def optional_worker(_company_id, "", _runner_kind), do: {:ok, nil}

  def optional_worker(company_id, worker_id, runner_kind) do
    case AgentRegistry.get_worker(company_id, worker_id) do
      %AgentWorker{} = worker -> validate_worker_for_runner(worker, runner_kind)
      nil -> {:error, {:not_found, "Worker not found"}}
    end
  end

  def ensure_run_can_start(%AgentWorker{execution_surface: "local_bridge"}, _runner_kind), do: :ok

  def ensure_run_can_start(_worker, runner_kind) when runner_kind in @async_runner_kinds, do: :ok

  def ensure_run_can_start(nil, _runner_kind),
    do: {:error, {:bad_request, "Selected work needs an assigned worker"}}

  def ensure_run_can_start(%AgentWorker{}, _runner_kind),
    do: {:error, {:bad_request, "Selected work cannot start yet"}}

  def after_run_created(
        %AgentWorker{execution_surface: "local_bridge"} = worker,
        %WorkRun{} = run
      ) do
    case AgentRegistry.create_worker_assignment(worker.company_id, worker.id, %{
           work_run_id: run.id
         }) do
      {:ok, _assignment} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def after_run_created(_worker, %WorkRun{runner_kind: runner_kind} = run)
      when runner_kind in @async_runner_kinds do
    case WorkRuns.enqueue_start(run) do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def after_run_created(_worker, _run),
    do: {:error, {:bad_request, "Selected work cannot start yet"}}

  defp validate_worker_for_runner(%AgentWorker{} = worker, runner_kind) do
    if worker_can_run?(worker, runner_kind) do
      {:ok, worker}
    else
      {:error, {:bad_request, "This worker cannot run the selected work"}}
    end
  end

  defp worker_can_run?(_worker, nil), do: true

  defp worker_can_run?(%AgentWorker{} = worker, runner_kind) do
    case Map.fetch(@runner_worker_shapes, runner_kind) do
      {:ok, shape} ->
        worker.agent_kind == shape.agent_kind and
          worker.execution_surface == shape.execution_surface and
          worker.runner_kind in shape.runner_kinds

      :error ->
        worker.runner_kind == runner_kind
    end
  end

  defp retryable_run(%WorkRun{status: status}) when status in ["failed", "canceled"], do: :ok

  defp retryable_run(_run), do: {:error, {:bad_request, "Run cannot be retried now"}}

  defp required_signed_wallet(%{"wallet_address" => wallet_address})
       when is_binary(wallet_address) and wallet_address != "",
       do: {:ok, wallet_address}

  defp required_signed_wallet(_claims), do: :error

  defp run_worker_id(%WorkRun{worker_id: nil}),
    do: {:error, {:forbidden, "Signed agent is not assigned to this run"}}

  defp run_worker_id(%WorkRun{worker_id: worker_id}), do: {:ok, worker_id}

  defp ensure_claims_match_worker(claims, %AgentWorker{siwa_subject: subject})
       when is_map(claims) and is_map(subject) do
    if Enum.all?(@worker_claim_fields, &same_claim?(subject, claims, &1)) do
      :ok
    else
      {:error, {:forbidden, "Signed agent is not assigned to this worker"}}
    end
  end

  defp ensure_claims_match_worker(_claims, _worker),
    do: {:error, {:forbidden, "Signed agent is not assigned to this worker"}}

  defp same_claim?(stored_claims, current_claims, field) do
    stored = normalize_claim(Map.get(stored_claims, field))
    current = normalize_claim(Map.get(current_claims, field))

    not is_nil(stored) and stored == current
  end

  defp normalize_claim(value) when is_binary(value), do: String.downcase(value)
  defp normalize_claim(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_claim(_value), do: nil

  defp retry_run_attrs(%WorkRun{} = run) do
    %{
      company_id: run.company_id,
      work_item_id: run.work_item_id,
      parent_run_id: run.parent_run_id,
      root_run_id: run.root_run_id,
      delegated_by_run_id: run.delegated_by_run_id,
      worker_id: run.worker_id,
      runtime_profile_id: run.runtime_profile_id,
      runner_kind: run.runner_kind,
      workspace_path: run.workspace_path,
      visibility: run.visibility,
      attempt: run.attempt + 1,
      input: run.input || %{},
      metadata: Map.merge(run.metadata || %{}, %{"retried_from_run_id" => run.id})
    }
  end

  defp checkpoint_attrs(%RuntimeProfile{} = runtime, params) do
    %{
      company_id: runtime.company_id,
      runtime_profile_id: runtime.id,
      work_run_id: parse_optional_id(Map.get(params, "work_run_id")),
      checkpoint_ref: Map.get(params, "checkpoint_ref"),
      status: Map.get(params, "status", "ready"),
      captured_at: parse_datetime(Map.get(params, "captured_at")),
      metadata: Map.get(params, "metadata", %{})
    }
  end

  defp hosted_sprite_runtime?(%RuntimeProfile{
         execution_surface: "hosted_sprite",
         billing_mode: "platform_hosted",
         platform_agent: %Agent{}
       }),
       do: true

  defp hosted_sprite_runtime?(_runtime), do: false

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil
  defp parse_optional_id(value), do: parse_id(value)

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      _other -> value
    end
  end

  defp parse_datetime(value), do: value

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _other -> value
    end
  end

  defp parse_id(value), do: value

  defp now, do: PlatformPhx.Clock.now()
end
