defmodule PlatformPhxWeb.Api.RegentWorkRuntimeController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.Companies
  alias PlatformPhx.AgentPlatform.RegentWorkRuntime, as: RWR
  alias PlatformPhx.Orchestration
  alias PlatformPhx.ProofPackets
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.RuntimeService
  alias PlatformPhx.Work.WorkItem
  alias PlatformPhx.WorkRuns.ApprovalRequest
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhxWeb.ApiRequest

  def account(conn, _params) do
    case current_human(conn) do
      nil ->
        json(conn, %{ok: true, authenticated: false, companies: []})

      human ->
        json(conn, %{
          ok: true,
          authenticated: true,
          companies: Enum.map(Companies.list_owned_companies(human), &company_payload/1)
        })
    end
  end

  def work_items(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      items = RWR.list_owned_work_items(human.id, company.id)

      json(conn, %{
        ok: true,
        company_id: company.id,
        work_items: Enum.map(items, &work_item_payload/1)
      })
    end)
  end

  def create_work_item(conn, %{"company_id" => company_id} = params) do
    with_owned_company(conn, company_id, fn company, _human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           {:ok, attrs} <- ApiRequest.cast(params, work_item_fields()),
           {:ok, item} <- RWR.create_work_item(work_item_attrs(company.id, attrs)) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, work_item: work_item_payload(item)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def work_item(conn, %{"company_id" => company_id, "work_item_id" => work_item_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_work_item(human.id, company.id, work_item_id) do
        %WorkItem{} = item -> json(conn, %{ok: true, work_item: work_item_payload(item)})
        nil -> respond_error(conn, {:not_found, "Work item not found"})
      end
    end)
  end

  def start_run(conn, %{"company_id" => company_id, "work_item_id" => work_item_id} = params) do
    with_owned_company(conn, company_id, fn company, human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_work_item_id_matches_path(conn, work_item_id),
           {:ok, attrs} <- ApiRequest.cast(params, run_fields()),
           %WorkItem{} = item <- owned_work_item(human.id, company.id, work_item_id),
           {:ok, worker} <-
             RWR.optional_worker(
               company.id,
               Map.get(attrs, "worker_id"),
               Map.get(attrs, "runner_kind")
             ),
           :ok <- RWR.ensure_run_can_start(worker, Map.get(attrs, "runner_kind")),
           {:ok, run} <- RWR.create_run(run_attrs(company.id, item.id, worker, attrs)),
           :ok <- RWR.after_run_created(worker, run) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, run: run_payload(run)})
      else
        nil -> respond_error(conn, {:not_found, "Work item not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def run(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run -> json(conn, %{ok: true, run: run_payload(run)})
        nil -> respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def run_tree(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          json(conn, %{ok: true, run_id: run.id, tree: run_tree_payload(RWR.run_tree(run))})

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def cancel_run(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          case RWR.cancel_run(run) do
            {:ok, run} -> json(conn, %{ok: true, run: run_payload(run)})
            {:error, reason} -> respond_error(conn, reason)
          end

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def retry_run(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      with %WorkRun{} = run <- owned_run(human.id, company.id, run_id),
           {:ok, retry} <- RWR.retry_run(run) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, run: run_payload(retry)})
      else
        nil -> respond_error(conn, {:not_found, "Run not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def run_events(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          events = RWR.list_run_events(company.id, run.id)
          json(conn, %{ok: true, run_id: run.id, events: Enum.map(events, &event_payload/1)})

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def run_event_stream(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          events = RWR.replay_run_events(company.id, run.id)

          json(conn, %{
            ok: true,
            run_id: run.id,
            stream: %{mode: "replay"},
            events: Enum.map(events, &event_payload/1)
          })

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def artifacts(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          artifacts = RWR.list_artifacts(company.id, run.id)

          json(conn, %{
            ok: true,
            run_id: run.id,
            artifacts: Enum.map(artifacts, &artifact_payload/1)
          })

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def artifact(conn, %{
        "company_id" => company_id,
        "run_id" => run_id,
        "artifact_id" => artifact_id
      }) do
    with_owned_company(conn, company_id, fn company, human ->
      with %WorkRun{} = run <- owned_run(human.id, company.id, run_id),
           %WorkArtifact{} = artifact <- RWR.get_run_artifact(company.id, run.id, artifact_id) do
        json(conn, %{ok: true, artifact: artifact_payload(artifact)})
      else
        nil -> respond_error(conn, {:not_found, "Artifact not found"})
      end
    end)
  end

  def company_artifact(conn, %{"company_id" => company_id, "artifact_id" => artifact_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      case RWR.get_company_artifact(company.id, artifact_id) do
        %WorkArtifact{} = artifact ->
          json(conn, %{ok: true, artifact: artifact_payload(artifact)})

        nil ->
          respond_error(conn, {:not_found, "Artifact not found"})
      end
    end)
  end

  def publish_artifact(conn, %{
        "company_id" => company_id,
        "run_id" => run_id,
        "artifact_id" => artifact_id
      }) do
    with_owned_company(conn, company_id, fn company, human ->
      with %WorkRun{} = run <- owned_run(human.id, company.id, run_id),
           %WorkArtifact{} = artifact <- RWR.get_run_artifact(company.id, run.id, artifact_id),
           {:ok, artifact} <- RWR.publish_artifact(artifact) do
        json(conn, %{ok: true, artifact: artifact_payload(artifact)})
      else
        nil -> respond_error(conn, {:not_found, "Artifact not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def approvals(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          approvals = RWR.list_approvals(company.id, run.id)

          json(conn, %{
            ok: true,
            run_id: run.id,
            approvals: Enum.map(approvals, &approval_payload/1)
          })

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def approval(conn, %{
        "company_id" => company_id,
        "run_id" => run_id,
        "approval_id" => approval_id
      }) do
    with_owned_company(conn, company_id, fn company, human ->
      with %WorkRun{} = run <- owned_run(human.id, company.id, run_id),
           %ApprovalRequest{} = approval <- RWR.get_approval(company.id, run.id, approval_id) do
        json(conn, %{ok: true, approval: approval_payload(approval)})
      else
        nil -> respond_error(conn, {:not_found, "Approval not found"})
      end
    end)
  end

  def resolve_approval(
        conn,
        %{"company_id" => company_id, "run_id" => run_id, "approval_id" => approval_id} = params
      ) do
    with_owned_company(conn, company_id, fn company, human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           %WorkRun{} = run <- owned_run(human.id, company.id, run_id),
           :ok <- body_run_id_matches_path(conn, run.id),
           %ApprovalRequest{} = approval <- RWR.get_approval(company.id, run.id, approval_id),
           {:ok, approval} <- RWR.resolve_approval(approval, human.id, params) do
        json(conn, %{ok: true, approval: approval_payload(approval)})
      else
        nil -> respond_error(conn, {:not_found, "Approval not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def workers(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      workers = RWR.list_workers(company.id)

      json(conn, %{
        ok: true,
        company_id: company.id,
        workers: Enum.map(workers, &worker_payload/1)
      })
    end)
  end

  def runtimes(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      runtimes = RWR.list_runtimes(company.id)

      json(conn, %{
        ok: true,
        company_id: company.id,
        runtimes: Enum.map(runtimes, &runtime_payload/1)
      })
    end)
  end

  def create_runtime(conn, %{"company_id" => company_id} = params) do
    with_owned_company(conn, company_id, fn company, _human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           {:ok, attrs} <- ApiRequest.cast(params, runtime_fields()),
           {:ok, runtime} <-
             RWR.create_runtime(runtime_attrs(company.id, attrs)) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, runtime: runtime_payload(runtime)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def runtime(conn, %{"company_id" => company_id, "runtime_id" => runtime_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      case owned_runtime(company.id, runtime_id) do
        %RuntimeProfile{} = runtime -> json(conn, %{ok: true, runtime: runtime_payload(runtime)})
        nil -> respond_error(conn, {:not_found, "Runtime not found"})
      end
    end)
  end

  def checkpoint_runtime(conn, %{"company_id" => company_id, "runtime_id" => runtime_id} = params) do
    with_owned_company(conn, company_id, fn company, _human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_runtime_id_matches_path(conn, runtime_id),
           {:ok, attrs} <- ApiRequest.cast(params, checkpoint_fields()),
           %RuntimeProfile{} = runtime <- owned_runtime(company.id, runtime_id),
           {:ok, checkpoint} <- RWR.create_runtime_checkpoint(runtime, attrs) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, checkpoint: checkpoint_payload(checkpoint)})
      else
        nil -> respond_error(conn, {:not_found, "Runtime not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def restore_runtime(conn, %{"company_id" => company_id, "runtime_id" => runtime_id} = params) do
    with_owned_company(conn, company_id, fn company, _human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_runtime_id_matches_path(conn, runtime_id),
           {:ok, attrs} <- ApiRequest.cast(params, restore_fields()),
           %RuntimeProfile{} = runtime <- owned_runtime(company.id, runtime_id),
           %RuntimeCheckpoint{} = checkpoint <- owned_checkpoint(company.id, runtime.id, attrs),
           {:ok, checkpoint} <- RWR.request_runtime_restore(runtime, checkpoint) do
        json(conn, %{
          ok: true,
          runtime: runtime_payload(runtime),
          checkpoint: checkpoint_payload(checkpoint),
          restore: %{status: "accepted"}
        })
      else
        nil -> respond_error(conn, {:not_found, "Runtime checkpoint not found"})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def pause_runtime(conn, %{"company_id" => company_id, "runtime_id" => runtime_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_runtime(company.id, runtime_id) do
        %RuntimeProfile{} = runtime -> change_runtime_state(conn, runtime, "paused", human)
        nil -> respond_error(conn, {:not_found, "Runtime not found"})
      end
    end)
  end

  def resume_runtime(conn, %{"company_id" => company_id, "runtime_id" => runtime_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_runtime(company.id, runtime_id) do
        %RuntimeProfile{} = runtime -> change_runtime_state(conn, runtime, "active", human)
        nil -> respond_error(conn, {:not_found, "Runtime not found"})
      end
    end)
  end

  def runtime_services(conn, %{"company_id" => company_id, "runtime_id" => runtime_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      case owned_runtime(company.id, runtime_id) do
        %RuntimeProfile{} = runtime ->
          services = RWR.list_runtime_services(company.id, runtime.id)

          json(conn, %{
            ok: true,
            company_id: company.id,
            runtime_id: runtime.id,
            services: Enum.map(services, &service_payload/1)
          })

        nil ->
          respond_error(conn, {:not_found, "Runtime not found"})
      end
    end)
  end

  def runtime_health(conn, %{"company_id" => company_id, "runtime_id" => runtime_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      case owned_runtime(company.id, runtime_id) do
        %RuntimeProfile{} = runtime ->
          json(conn, %{
            ok: true,
            company_id: company.id,
            runtime_id: runtime.id,
            health: runtime_health_payload(runtime)
          })

        nil ->
          respond_error(conn, {:not_found, "Runtime not found"})
      end
    end)
  end

  def relationships(conn, %{"company_id" => company_id, "source_id" => source_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      relationships = RWR.list_relationships(company.id, source_id)

      json(conn, %{
        ok: true,
        company_id: company.id,
        relationships: Enum.map(relationships, &relationship_payload/1)
      })
    end)
  end

  def create_relationship(conn, %{"company_id" => company_id, "source_id" => source_id} = params) do
    with_owned_company(conn, company_id, fn company, _human ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           {:ok, attrs} <- ApiRequest.cast(params, relationship_fields()),
           {:ok, relationship} <-
             RWR.create_relationship(company.id, source_id, attrs) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, relationship: relationship_payload(relationship)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def execution_pool(conn, %{"company_id" => company_id, "manager_id" => manager_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      pool = RWR.list_execution_pool(company.id, manager_id)
      json(conn, %{ok: true, company_id: company.id, workers: Enum.map(pool, &worker_payload/1)})
    end)
  end

  def delete_relationship(conn, %{
        "company_id" => company_id,
        "relationship_id" => relationship_id
      }) do
    with_owned_company(conn, company_id, fn company, _human ->
      case RWR.delete_relationship(company.id, relationship_id) do
        {:ok, relationship} ->
          json(conn, %{ok: true, relationship: relationship_payload(relationship)})

        {:error, reason} ->
          respond_error(conn, reason)
      end
    end)
  end

  def register_worker(conn, %{"company_id" => company_id} = params) do
    with_signed_company(conn, company_id, fn company ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           {:ok, attrs} <- ApiRequest.cast(params, worker_fields()),
           {:ok, profile, worker} <- create_worker_with_profile(company.id, attrs, conn) do
        conn
        |> put_status(:created)
        |> json(%{
          ok: true,
          agent_profile: profile_payload(profile),
          worker: worker_payload(worker)
        })
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def heartbeat(conn, %{"company_id" => company_id, "worker_id" => worker_id} = params) do
    with_signed_worker(conn, company_id, worker_id, fn company, _worker ->
      case RWR.heartbeat_worker(company.id, worker_id, params) do
        {:ok, worker} -> json(conn, %{ok: true, worker: worker_payload(worker)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def assignments(conn, %{"company_id" => company_id, "worker_id" => worker_id}) do
    with_signed_worker(conn, company_id, worker_id, fn company, _worker ->
      assignments = RWR.list_worker_assignments(company.id, worker_id)
      json(conn, %{ok: true, assignments: Enum.map(assignments, &assignment_payload/1)})
    end)
  end

  def claim_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case RWR.claim_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def release_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case RWR.release_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def complete_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case RWR.complete_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def append_event(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, _run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, attrs} <- ApiRequest.cast(params, event_fields()),
           {:ok, event} <- RunEvents.append_event(attrs) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, event: event_payload(event)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def append_event_batch(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, _run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, attrs} <- ApiRequest.cast(params, event_batch_fields()),
           {:ok, events} <- RWR.append_event_batch(attrs, company.id, parse_id(run_id)) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, run_id: parse_id(run_id), events: Enum.map(events, &event_payload/1)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def create_artifact(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, attrs} <- ApiRequest.cast(params, artifact_fields()),
           {:ok, artifact} <- ProofPackets.record_artifact(artifact_attrs(run, attrs)) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, artifact: artifact_payload(artifact)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def request_delegation(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, attrs} <- cast_delegation_request(params),
           {:ok, result} <-
             Orchestration.handle_delegation_request(run, attrs, actor_context(company.id, run)) do
        conn
        |> put_status(:created)
        |> json(%{
          ok: true,
          target_worker: worker_payload(result.target_worker),
          child_runs: Enum.map(result.child_runs, &run_payload/1)
        })
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  defp with_owned_company(conn, company_id, fun) do
    case current_human(conn) do
      nil ->
        respond_error(conn, {:unauthorized, "Sign in before using company work"})

      human ->
        case Companies.get_owned_company(human, parse_id(company_id)) do
          %Company{} = company -> fun.(company, human)
          nil -> respond_error(conn, {:not_found, "Company not found"})
        end
    end
  end

  defp with_signed_company(conn, company_id, fun) do
    case RWR.signed_company(company_id, current_agent_claims(conn)) do
      {:ok, %Company{} = company} -> fun.(company)
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp with_signed_worker(conn, company_id, worker_id, fun) do
    case RWR.signed_worker(company_id, worker_id, current_agent_claims(conn)) do
      {:ok, company, worker} -> fun.(company, worker)
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp with_signed_assignment_worker(conn, company_id, assignment_id, fun) do
    case RWR.signed_assignment_worker(company_id, assignment_id, current_agent_claims(conn)) do
      {:ok, company, worker, assignment} -> fun.(company, worker, assignment)
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp with_signed_run_worker(conn, company_id, run_id, fun) do
    case RWR.signed_run_worker(company_id, run_id, current_agent_claims(conn)) do
      {:ok, company, run, worker} -> fun.(company, run, worker)
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end

  defp current_agent_claims(conn), do: conn.assigns[:current_agent_claims] || %{}

  defp body_company_id_matches_path(conn, company_id),
    do:
      body_id_matches_path(conn, "company_id", company_id, "Company id does not match the route")

  defp body_run_id_matches_path(conn, run_id),
    do: body_id_matches_path(conn, "run_id", run_id, "Run id does not match the route")

  defp body_runtime_id_matches_path(conn, runtime_id),
    do:
      body_id_matches_path(conn, "runtime_id", runtime_id, "Runtime id does not match the route")

  defp body_work_item_id_matches_path(conn, work_item_id),
    do:
      body_id_matches_path(
        conn,
        "work_item_id",
        work_item_id,
        "Work item id does not match the route"
      )

  defp body_id_matches_path(conn, field, path_id, message) do
    body_value = Map.get(conn.body_params || %{}, field)

    if to_string(body_value) == to_string(path_id),
      do: :ok,
      else: {:error, {:bad_request, message}}
  end

  defp owned_work_item(human_id, company_id, work_item_id) do
    human_id
    |> RWR.list_owned_work_items(company_id)
    |> Enum.find(&(to_string(&1.id) == to_string(work_item_id)))
  end

  defp owned_run(human_id, company_id, run_id) do
    RWR.get_owned_run(human_id, company_id, run_id)
  end

  defp owned_runtime(company_id, runtime_id) do
    RWR.get_runtime(company_id, runtime_id)
  end

  defp owned_checkpoint(company_id, runtime_id, params) do
    RWR.get_checkpoint(company_id, runtime_id, Map.get(params, "checkpoint_id"))
  end

  defp change_runtime_state(conn, %RuntimeProfile{} = runtime, target_state, human) do
    with {:ok, updated_runtime} <- RWR.change_runtime_state(runtime, target_state, human) do
      json(conn, %{ok: true, runtime: runtime_payload(updated_runtime)})
    else
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp work_item_fields do
    [
      {"title", :string, required: true},
      {"description", :string, []},
      {"priority", :string, default: "normal"},
      {"visibility", :string, default: "operator"},
      {"metadata", :map, default: %{}}
    ]
  end

  defp run_fields do
    [
      {"worker_id", :integer, []},
      {"runner_kind", :string, []},
      {"instructions", :string, []},
      {"metadata", :map, default: %{}}
    ]
  end

  defp runtime_fields do
    [
      {"platform_agent_id", :integer, []},
      {"name", :string, required: true},
      {"runner_kind", :string, required: true},
      {"execution_surface", :string, required: true},
      {"billing_mode", :string, required: true},
      {"status", :string, default: "active"},
      {"visibility", :string, default: "operator"},
      {"config", :map, default: %{}},
      {"metadata", :map, default: %{}}
    ]
  end

  defp checkpoint_fields do
    [
      {"work_run_id", :integer, []},
      {"checkpoint_ref", :string, []},
      {"status", :string, default: "ready"},
      {"captured_at", :string, []},
      {"metadata", :map, default: %{}}
    ]
  end

  defp restore_fields, do: [{"checkpoint_id", :integer, required: true}]

  defp relationship_fields do
    [
      {"source_agent_profile_id", :integer, []},
      {"target_agent_profile_id", :integer, []},
      {"source_worker_id", :integer, []},
      {"target_worker_id", :integer, []},
      {"relationship_kind", :string, required: true},
      {"status", :string, default: "active"},
      {"max_parallel_runs", :integer, []},
      {"metadata", :map, default: %{}}
    ]
  end

  defp worker_fields do
    [
      {"agent_kind", :string, required: true},
      {"worker_role", :string, required: true},
      {"execution_surface", :string, required: true},
      {"runner_kind", :string, required: true},
      {"billing_mode", :string, required: true},
      {"trust_scope", :string, required: true},
      {"reported_usage_policy", :string, []},
      {"display_name", :string, []},
      {"endpoint_url", :string, []},
      {"capabilities", :list, default: []}
    ]
  end

  defp event_fields do
    [
      {"company_id", :integer, required: true},
      {"run_id", :integer, required: true},
      {"kind", :string, required: true},
      {"actor_kind", :string, []},
      {"actor_id", :string, []},
      {"visibility", :string, []},
      {"sensitivity", :string, []},
      {"payload", :map, default: %{}},
      {"idempotency_key", :string, []},
      {"sequence", :integer, []},
      {"occurred_at", :string, []}
    ]
  end

  defp event_batch_fields, do: [{"events", :list, required: true}]

  defp artifact_fields do
    [
      {"artifact_type", :string, required: true},
      {"title", :string, []},
      {"body", :string, []},
      {"url", :string, []},
      {"visibility", :string, default: "operator"},
      {"metadata", :map, default: %{}},
      {"publish_action", :string, []}
    ]
  end

  defp delegation_fields do
    [
      {"company_id", :integer, required: true},
      {"run_id", :integer, required: true},
      {"work_item_id", :integer, []},
      {"relationship_kind", :enum,
       values: ["manager_of", "preferred_executor", "can_delegate_to", "reports_to"]},
      {"requested_runner_kind", :enum,
       required: true,
       values: [
         "hermes_local_manager",
         "hermes_hosted_manager",
         "openclaw_local_manager",
         "codex_exec",
         "codex_app_server",
         "openclaw_local_executor",
         "openclaw_code_agent_local",
         "fake",
         "custom_worker"
       ]},
      {"preferred_agent_kind", :enum, values: ["codex", "openclaw", "custom"]},
      {"target_agent_profile_id", :integer, []},
      {"target_worker_id", :integer, []},
      {"execution_surface", :enum,
       values: ["hosted_sprite", "local_bridge", "external_webhook", "manager_decides"]},
      {"strategy", :enum, required: true, values: ["parallel", "serial", "manager_decides"]},
      {"tasks", :list, required: true},
      {"budget_limit_usd_cents", :integer, []},
      {"instructions", :string, []},
      {"metadata", :map, default: %{}}
    ]
  end

  defp delegation_task_fields do
    [
      {"title", :string, required: true},
      {"instructions", :string, []},
      {"metadata", :map, default: %{}}
    ]
  end

  defp cast_delegation_request(params) do
    with {:ok, attrs} <- ApiRequest.cast(params, delegation_fields()),
         {:ok, tasks} <- cast_delegation_tasks(Map.get(attrs, "tasks")) do
      {:ok, Map.put(attrs, "tasks", tasks)}
    end
  end

  defp cast_delegation_tasks(tasks) when is_list(tasks) and tasks != [] do
    tasks
    |> Enum.reduce_while({:ok, []}, fn task, {:ok, acc} ->
      case ApiRequest.cast(task, delegation_task_fields()) do
        {:ok, attrs} -> {:cont, {:ok, [attrs | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, tasks} -> {:ok, Enum.reverse(tasks)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cast_delegation_tasks(_tasks), do: {:error, {:bad_request, "tasks is required"}}

  defp work_item_attrs(company_id, params) do
    %{
      company_id: company_id,
      title: Map.get(params, "title"),
      body: Map.get(params, "description"),
      priority: Map.get(params, "priority", "normal"),
      visibility: Map.get(params, "visibility", "operator"),
      metadata: Map.get(params, "metadata", %{})
    }
  end

  defp run_attrs(company_id, work_item_id, worker, params) do
    %{
      company_id: company_id,
      work_item_id: work_item_id,
      worker_id: worker && worker.id,
      runtime_profile_id: worker && worker.runtime_profile_id,
      runner_kind: Map.get(params, "runner_kind"),
      input: %{
        instructions: Map.get(params, "instructions"),
        metadata: Map.get(params, "metadata", %{})
      },
      metadata: Map.get(params, "metadata", %{})
    }
  end

  defp runtime_attrs(company_id, params) do
    %{
      company_id: company_id,
      platform_agent_id: parse_optional_id(Map.get(params, "platform_agent_id")),
      name: Map.get(params, "name"),
      runner_kind: Map.get(params, "runner_kind"),
      execution_surface: Map.get(params, "execution_surface"),
      billing_mode: Map.get(params, "billing_mode"),
      status: Map.get(params, "status", "active"),
      visibility: Map.get(params, "visibility", "operator"),
      config: Map.get(params, "config", %{}),
      metadata: Map.get(params, "metadata", %{})
    }
  end

  defp run_tree_payload(%{run: %WorkRun{} = run, children: children}) do
    %{
      run: run_payload(run),
      children: Enum.map(children, &run_tree_payload/1)
    }
  end

  defp create_worker_with_profile(company_id, params, conn) do
    RWR.register_worker_with_profile(
      company_id,
      params,
      conn.assigns[:current_agent_claims] || %{}
    )
  end

  defp artifact_attrs(%WorkRun{} = run, params) do
    %{
      company_id: run.company_id,
      work_item_id: run.work_item_id,
      run_id: run.id,
      kind: Map.get(params, "artifact_type"),
      title: Map.get(params, "title"),
      content_inline: Map.get(params, "body"),
      uri: Map.get(params, "url"),
      visibility: Map.get(params, "visibility", "operator"),
      metadata: Map.get(params, "metadata", %{}),
      runner_kind: run.runner_kind,
      publish_action: Map.get(params, "publish_action")
    }
  end

  defp actor_context(company_id, %WorkRun{} = run) do
    %{
      company_id: company_id,
      worker_id: run.worker_id,
      actor_kind: "worker"
    }
  end

  defp respond_error(conn, :not_found), do: respond_error(conn, {:not_found, "Not found"})

  defp respond_error(conn, :worker_not_found),
    do: respond_error(conn, {:not_found, "Worker not found"})

  defp respond_error(conn, :run_not_found), do: respond_error(conn, {:not_found, "Run not found"})

  defp respond_error(conn, :run_worker_mismatch),
    do: respond_error(conn, {:bad_request, "Run is assigned to a different worker"})

  defp respond_error(conn, :cross_company_relationship),
    do: respond_error(conn, {:forbidden, "Relationship is outside this company"})

  defp respond_error(conn, :target_worker_not_eligible),
    do: respond_error(conn, {:forbidden, "Worker is not available for this manager"})

  defp respond_error(conn, :relationship_source_mismatch),
    do: respond_error(conn, {:bad_request, "Relationship source does not match the route"})

  defp respond_error(conn, :no_eligible_worker),
    do: respond_error(conn, {:not_found, "No available worker matched this request"})

  defp respond_error(conn, :explicit_publish_action_required),
    do: respond_error(conn, {:forbidden, "Publishing this artifact requires an explicit action"})

  defp respond_error(conn, {:approval_required, _details}),
    do: respond_error(conn, {:forbidden, "This work needs approval before it can continue"})

  defp respond_error(conn, {:delegation_rejected, _details}),
    do: respond_error(conn, {:forbidden, "Delegation is outside the current budget policy"})

  defp respond_error(conn, {%Ecto.Changeset{}, _details}),
    do: respond_error(conn, {:bad_request, "Invalid RWR request"})

  defp respond_error(conn, %Ecto.Changeset{}),
    do: respond_error(conn, {:bad_request, "Invalid RWR request"})

  defp respond_error(conn, reason) when is_atom(reason),
    do: respond_error(conn, {:bad_request, "Invalid RWR request"})

  defp respond_error(conn, {:bad_request, _message} = reason), do: ApiErrors.error(conn, reason)
  defp respond_error(conn, {:not_found, _message} = reason), do: ApiErrors.error(conn, reason)
  defp respond_error(conn, {:forbidden, _message} = reason), do: ApiErrors.error(conn, reason)
  defp respond_error(conn, {:unauthorized, _message} = reason), do: ApiErrors.error(conn, reason)

  defp respond_error(conn, {:payment_required, _message} = reason),
    do: ApiErrors.error(conn, reason)

  defp respond_error(conn, _reason),
    do: ApiErrors.error(conn, {:bad_request, "Invalid RWR request"})

  defp company_payload(%Company{} = company) do
    %{
      id: company.id,
      name: company.name,
      slug: company.slug,
      status: company.status
    }
  end

  defp profile_payload(profile) do
    %{
      id: profile.id,
      company_id: profile.company_id,
      name: profile.name,
      agent_kind: profile.agent_kind,
      default_runner_kind: profile.default_runner_kind,
      status: profile.status,
      visibility: profile.default_visibility
    }
  end

  defp work_item_payload(item) do
    %{
      id: item.id,
      company_id: item.company_id,
      title: item.title,
      description: item.body,
      status: item.status,
      priority: item.priority,
      visibility: item.visibility,
      desired_runner_kind: item.desired_runner_kind,
      assigned_worker_id: item.assigned_worker_id,
      assigned_agent_profile_id: item.assigned_agent_profile_id,
      created_at: iso8601(item.created_at),
      updated_at: iso8601(item.updated_at)
    }
  end

  defp run_payload(run) do
    %{
      id: run.id,
      company_id: run.company_id,
      work_item_id: run.work_item_id,
      parent_run_id: run.parent_run_id,
      root_run_id: run.root_run_id,
      worker_id: run.worker_id,
      runtime_profile_id: run.runtime_profile_id,
      runner_kind: run.runner_kind,
      status: run.status,
      visibility: run.visibility,
      summary: run.summary,
      failure_reason: run.failure_reason,
      cost_usd: money(run.cost_usd),
      created_at: iso8601(run.created_at),
      updated_at: iso8601(run.updated_at)
    }
  end

  defp event_payload(event) do
    %{
      id: event.id,
      company_id: event.company_id,
      run_id: event.run_id,
      sequence: event.sequence,
      kind: event.kind,
      actor_kind: event.actor_kind,
      actor_id: event.actor_id,
      visibility: event.visibility,
      sensitivity: event.sensitivity,
      payload: event.payload,
      occurred_at: iso8601(event.occurred_at)
    }
  end

  defp artifact_payload(artifact) do
    %{
      id: artifact.id,
      company_id: artifact.company_id,
      work_item_id: artifact.work_item_id,
      run_id: artifact.run_id,
      artifact_type: artifact.kind,
      title: artifact.title,
      url: artifact.uri,
      visibility: artifact.visibility,
      attestation_level: artifact.attestation_level,
      created_at: iso8601(artifact.created_at),
      updated_at: iso8601(artifact.updated_at)
    }
  end

  defp approval_payload(%ApprovalRequest{} = approval) do
    %{
      id: approval.id,
      company_id: approval.company_id,
      run_id: approval.work_run_id,
      approval_type: approval.kind,
      status: approval.status,
      requested_by_actor_kind: approval.requested_by_actor_kind,
      requested_by_actor_id: approval.requested_by_actor_id,
      risk_summary: approval.risk_summary,
      payload: approval.payload || %{},
      resolved_by_human_id: approval.resolved_by_human_id,
      resolved_at: iso8601(approval.resolved_at),
      expires_at: iso8601(approval.expires_at),
      created_at: iso8601(approval.created_at),
      updated_at: iso8601(approval.updated_at)
    }
  end

  defp worker_payload(worker) do
    %{
      id: worker.id,
      company_id: worker.company_id,
      agent_profile_id: worker.agent_profile_id,
      runtime_profile_id: worker.runtime_profile_id,
      name: worker.name,
      agent_kind: worker.agent_kind,
      worker_role: worker.worker_role,
      execution_surface: worker.execution_surface,
      runner_kind: worker.runner_kind,
      billing_mode: worker.billing_mode,
      trust_scope: worker.trust_scope,
      reported_usage_policy: worker.reported_usage_policy,
      status: worker.status,
      last_heartbeat_at: iso8601(worker.last_heartbeat_at)
    }
  end

  defp runtime_payload(runtime) do
    %{
      id: runtime.id,
      company_id: runtime.company_id,
      platform_agent_id: runtime.platform_agent_id,
      name: runtime.name,
      runner_kind: runtime.runner_kind,
      execution_surface: runtime.execution_surface,
      billing_mode: runtime.billing_mode,
      status: runtime.status,
      visibility: runtime.visibility,
      config: runtime.config || %{},
      metadata: runtime.metadata || %{}
    }
  end

  defp service_payload(%RuntimeService{} = service) do
    %{
      id: service.id,
      company_id: service.company_id,
      runtime_profile_id: service.runtime_profile_id,
      name: service.name,
      service_kind: service.service_kind,
      status: service.status,
      endpoint_url: service.endpoint_url,
      metadata: service.metadata || %{}
    }
  end

  defp checkpoint_payload(%RuntimeCheckpoint{} = checkpoint) do
    %{
      id: checkpoint.id,
      company_id: checkpoint.company_id,
      runtime_profile_id: checkpoint.runtime_profile_id,
      work_run_id: checkpoint.work_run_id,
      checkpoint_ref: checkpoint.checkpoint_ref,
      status: checkpoint.status,
      protected: checkpoint.protected,
      captured_at: iso8601(checkpoint.captured_at),
      metadata: checkpoint.metadata || %{},
      created_at: iso8601(checkpoint.created_at),
      updated_at: iso8601(checkpoint.updated_at)
    }
  end

  defp runtime_health_payload(%RuntimeProfile{} = runtime) do
    RWR.runtime_health(runtime)
  end

  defp runtime_health_payload(_runtime) do
    RWR.runtime_health(nil)
  end

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil
  defp parse_optional_id(value), do: parse_id(value)

  defp relationship_payload(relationship) do
    %{
      id: relationship.id,
      company_id: relationship.company_id,
      source_agent_profile_id: relationship.source_agent_profile_id,
      target_agent_profile_id: relationship.target_agent_profile_id,
      source_worker_id: relationship.source_worker_id,
      target_worker_id: relationship.target_worker_id,
      relationship_kind: relationship.relationship_kind,
      status: relationship.status,
      max_parallel_runs: relationship.max_parallel_runs
    }
  end

  defp assignment_payload(assignment) do
    %{
      id: assignment.id,
      company_id: assignment.company_id,
      worker_id: assignment.worker_id,
      work_run_id: assignment.work_run_id,
      status: assignment.status,
      claimed_at: iso8601(assignment.claimed_at),
      leased_until: iso8601(assignment.leased_until),
      released_at: iso8601(assignment.released_at)
    }
  end

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _other -> value
    end
  end

  defp parse_id(value), do: value
  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp money(nil), do: "0"
  defp money(%Decimal{} = value), do: Decimal.to_string(value)
  defp money(value), do: to_string(value)
end
