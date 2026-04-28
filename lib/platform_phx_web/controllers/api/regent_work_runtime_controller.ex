defmodule PlatformPhxWeb.Api.RegentWorkRuntimeController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Orchestration
  alias PlatformPhx.ProofPackets
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.RuntimeService
  alias PlatformPhx.Work
  alias PlatformPhx.Work.WorkItem
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhxWeb.ApiErrors

  @async_runner_kinds ["fake", "codex_exec", "codex_app_server"]
  @local_runner_kinds [
    "hermes_local_manager",
    "openclaw_local_manager",
    "openclaw_local_executor",
    "openclaw_code_agent_local"
  ]
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
  @worker_claim_fields ~w(wallet_address chain_id registry_address token_id)

  def account(conn, _params) do
    case current_human(conn) do
      nil ->
        json(conn, %{ok: true, authenticated: false, companies: []})

      human ->
        json(conn, %{
          ok: true,
          authenticated: true,
          companies: Enum.map(AgentPlatform.list_owned_companies(human), &company_payload/1)
        })
    end
  end

  def work_items(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      items = Work.list_items_for_owned_company(human.id, company.id)

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
           {:ok, item} <- Work.create_item(work_item_attrs(company.id, params)) do
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
           %WorkItem{} = item <- owned_work_item(human.id, company.id, work_item_id),
           {:ok, worker} <-
             optional_worker(
               company.id,
               Map.get(params, "worker_id"),
               Map.get(params, "runner_kind")
             ),
           :ok <- ensure_run_can_start(worker, Map.get(params, "runner_kind")),
           {:ok, run} <- WorkRuns.create_run(run_attrs(company.id, item.id, worker, params)),
           :ok <- after_run_created(worker, run) do
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

  def run_events(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          events = RunEvents.list_events(company.id, run.id)
          json(conn, %{ok: true, run_id: run.id, events: Enum.map(events, &event_payload/1)})

        nil ->
          respond_error(conn, {:not_found, "Run not found"})
      end
    end)
  end

  def artifacts(conn, %{"company_id" => company_id, "run_id" => run_id}) do
    with_owned_company(conn, company_id, fn company, human ->
      case owned_run(human.id, company.id, run_id) do
        %WorkRun{} = run ->
          artifacts = WorkRuns.list_artifacts(company.id, run.id)

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

  def workers(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      workers = AgentRegistry.list_workers_with_details(company.id)

      json(conn, %{
        ok: true,
        company_id: company.id,
        workers: Enum.map(workers, &worker_payload/1)
      })
    end)
  end

  def runtimes(conn, %{"company_id" => company_id}) do
    with_owned_company(conn, company_id, fn company, _human ->
      runtimes = RuntimeRegistry.list_runtime_profiles_with_details(company.id)

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
           {:ok, runtime} <-
             RuntimeRegistry.create_runtime_profile(runtime_attrs(company.id, params)) do
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
           %RuntimeProfile{} = runtime <- owned_runtime(company.id, runtime_id),
           {:ok, checkpoint} <- create_runtime_checkpoint(runtime, params) do
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
           %RuntimeProfile{} = runtime <- owned_runtime(company.id, runtime_id),
           %RuntimeCheckpoint{} = checkpoint <- owned_checkpoint(company.id, runtime.id, params) do
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
          services = RuntimeRegistry.list_runtime_services(company.id, runtime.id)

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
      relationships = AgentRegistry.list_relationships_for_member(company.id, source_id)

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
           {:ok, relationship} <-
             AgentRegistry.create_agent_relationship(company.id, source_id, params) do
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
      pool = AgentRegistry.list_execution_pool(company.id, manager_id)
      json(conn, %{ok: true, company_id: company.id, workers: Enum.map(pool, &worker_payload/1)})
    end)
  end

  def delete_relationship(conn, %{
        "company_id" => company_id,
        "relationship_id" => relationship_id
      }) do
    with_owned_company(conn, company_id, fn company, _human ->
      case AgentRegistry.delete_relationship(company.id, relationship_id) do
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
           {:ok, profile, worker} <- create_worker_with_profile(company.id, params, conn) do
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
      case AgentRegistry.heartbeat_worker(company.id, worker_id, params) do
        {:ok, worker} -> json(conn, %{ok: true, worker: worker_payload(worker)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def assignments(conn, %{"company_id" => company_id, "worker_id" => worker_id}) do
    with_signed_worker(conn, company_id, worker_id, fn company, _worker ->
      assignments = AgentRegistry.list_worker_assignments(company.id, worker_id)
      json(conn, %{ok: true, assignments: Enum.map(assignments, &assignment_payload/1)})
    end)
  end

  def claim_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case AgentRegistry.claim_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def release_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case AgentRegistry.release_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def complete_assignment(conn, %{"company_id" => company_id, "assignment_id" => assignment_id}) do
    with_signed_assignment_worker(conn, company_id, assignment_id, fn company,
                                                                      worker,
                                                                      assignment ->
      case AgentRegistry.complete_worker_assignment(company.id, worker.id, assignment.id) do
        {:ok, assignment} -> json(conn, %{ok: true, assignment: assignment_payload(assignment)})
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def append_event(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, _run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, event} <- RunEvents.append_event(params) do
        conn
        |> put_status(:created)
        |> json(%{ok: true, event: event_payload(event)})
      else
        {:error, reason} -> respond_error(conn, reason)
      end
    end)
  end

  def create_artifact(conn, %{"company_id" => company_id, "run_id" => run_id} = params) do
    with_signed_run_worker(conn, company_id, run_id, fn company, run, _worker ->
      with :ok <- body_company_id_matches_path(conn, company.id),
           :ok <- body_run_id_matches_path(conn, run_id),
           {:ok, artifact} <- ProofPackets.record_artifact(artifact_attrs(run, params)) do
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
           {:ok, result} <-
             Orchestration.handle_delegation_request(run, params, actor_context(company.id, run)) do
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
        case AgentPlatform.get_owned_company(human, parse_id(company_id)) do
          %Company{} = company -> fun.(company, human)
          nil -> respond_error(conn, {:not_found, "Company not found"})
        end
    end
  end

  defp with_signed_company(conn, company_id, fun) do
    case Repo.get(Company, parse_id(company_id)) |> Repo.preload(:owner_human) do
      %Company{} = company ->
        if agent_claims_match_company_owner?(conn.assigns[:current_agent_claims] || %{}, company) do
          fun.(company)
        else
          respond_error(conn, {:forbidden, "Signed agent is not connected to this company"})
        end

      nil ->
        respond_error(conn, {:not_found, "Company not found"})
    end
  end

  defp with_signed_worker(conn, company_id, worker_id, fun) do
    with_signed_company(conn, company_id, fn company ->
      case AgentRegistry.get_worker(company.id, worker_id) do
        %AgentWorker{} = worker ->
          case signed_agent_matches_worker(conn, worker) do
            :ok -> fun.(company, worker)
            {:error, reason} -> respond_error(conn, reason)
          end

        nil ->
          respond_error(conn, {:not_found, "Worker not found"})
      end
    end)
  end

  defp with_signed_assignment_worker(conn, company_id, assignment_id, fun) do
    with_signed_company(conn, company_id, fn company ->
      case AgentRegistry.get_worker_assignment(company.id, assignment_id) do
        nil ->
          respond_error(conn, {:not_found, "Assignment not found"})

        assignment ->
          case AgentRegistry.get_worker(company.id, assignment.worker_id) do
            %AgentWorker{} = worker ->
              case signed_agent_matches_worker(conn, worker) do
                :ok -> fun.(company, worker, assignment)
                {:error, reason} -> respond_error(conn, reason)
              end

            nil ->
              respond_error(conn, {:not_found, "Worker not found"})
          end
      end
    end)
  end

  defp with_signed_run_worker(conn, company_id, run_id, fun) do
    with_signed_company(conn, company_id, fn company ->
      case WorkRuns.get_run(company.id, run_id) do
        nil ->
          respond_error(conn, {:not_found, "Run not found"})

        %WorkRun{worker_id: nil} ->
          respond_error(conn, {:forbidden, "Signed agent is not assigned to this run"})

        %WorkRun{} = run ->
          case AgentRegistry.get_worker(company.id, run.worker_id) do
            %AgentWorker{} = worker ->
              case signed_agent_matches_worker(conn, worker) do
                :ok -> fun.(company, run, worker)
                {:error, reason} -> respond_error(conn, reason)
              end

            nil ->
              respond_error(conn, {:not_found, "Worker not found"})
          end
      end
    end)
  end

  defp signed_agent_matches_worker(conn, %AgentWorker{} = worker) do
    if agent_claims_match_worker?(conn.assigns[:current_agent_claims] || %{}, worker) do
      :ok
    else
      {:error, {:forbidden, "Signed agent is not assigned to this worker"}}
    end
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end

  defp agent_claims_match_company_owner?(%{"wallet_address" => wallet_address}, %Company{
         owner_human: owner
       }) do
    wallet_address = normalize_wallet(wallet_address)

    owner
    |> owner_wallets()
    |> Enum.any?(&(normalize_wallet(&1) == wallet_address))
  end

  defp agent_claims_match_company_owner?(_claims, _company), do: false

  defp agent_claims_match_worker?(claims, %AgentWorker{siwa_subject: subject})
       when is_map(claims) and is_map(subject) do
    Enum.all?(@worker_claim_fields, fn field ->
      stored = normalize_claim(Map.get(subject, field))
      current = normalize_claim(Map.get(claims, field))

      not is_nil(stored) and stored == current
    end)
  end

  defp agent_claims_match_worker?(_claims, _worker), do: false

  defp owner_wallets(nil), do: []

  defp owner_wallets(owner) do
    [owner.wallet_address | owner.wallet_addresses || []]
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_wallet(value) when is_binary(value), do: String.downcase(value)
  defp normalize_wallet(_value), do: nil

  defp normalize_claim(value) when is_binary(value), do: String.downcase(value)
  defp normalize_claim(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_claim(_value), do: nil

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
    |> Work.list_items_for_owned_company(company_id)
    |> Enum.find(&(to_string(&1.id) == to_string(work_item_id)))
  end

  defp owned_run(human_id, company_id, run_id) do
    case WorkRuns.get_owned_run(human_id, parse_id(run_id)) do
      %WorkRun{company_id: ^company_id} = run -> run
      _run -> nil
    end
  end

  defp owned_runtime(company_id, runtime_id) do
    RuntimeRegistry.get_runtime_profile(company_id, parse_id(runtime_id))
  end

  defp owned_checkpoint(company_id, runtime_id, params) do
    RuntimeRegistry.get_runtime_checkpoint(
      company_id,
      runtime_id,
      parse_id(Map.get(params, "checkpoint_id"))
    )
  end

  defp create_runtime_checkpoint(%RuntimeProfile{} = runtime, params) do
    attrs = checkpoint_attrs(runtime, params)

    if hosted_sprite_runtime?(runtime) do
      RuntimeRegistry.create_hosted_sprite_checkpoint(runtime, attrs)
    else
      RuntimeRegistry.create_runtime_checkpoint(attrs)
    end
  end

  defp hosted_sprite_runtime?(%RuntimeProfile{
         execution_surface: "hosted_sprite",
         billing_mode: "platform_hosted",
         platform_agent: %PlatformPhx.AgentPlatform.Agent{}
       }),
       do: true

  defp hosted_sprite_runtime?(_runtime), do: false

  defp change_runtime_state(conn, %RuntimeProfile{} = runtime, target_state, human) do
    runtime = Repo.preload(runtime, :platform_agent)

    result =
      case {target_state, runtime.platform_agent} do
        {"paused", %PlatformPhx.AgentPlatform.Agent{} = agent} ->
          RuntimeControl.pause(agent,
            actor_type: "human",
            human_user_id: human.id,
            source: "rwr_api"
          )

        {"active", %PlatformPhx.AgentPlatform.Agent{} = agent} ->
          RuntimeControl.resume(agent,
            actor_type: "human",
            human_user_id: human.id,
            source: "rwr_api"
          )

        _other ->
          {:ok, nil}
      end

    with {:ok, _agent} <- result,
         {:ok, updated_runtime} <-
           RuntimeRegistry.update_runtime_profile_status(runtime, target_state) do
      json(conn, %{ok: true, runtime: runtime_payload(updated_runtime)})
    else
      {:error, reason} -> respond_error(conn, reason)
    end
  end

  defp optional_worker(_company_id, nil, runner_kind) when runner_kind in @local_runner_kinds,
    do: {:error, {:bad_request, "Local work needs an assigned local worker"}}

  defp optional_worker(_company_id, "", runner_kind) when runner_kind in @local_runner_kinds,
    do: {:error, {:bad_request, "Local work needs an assigned local worker"}}

  defp optional_worker(_company_id, nil, _runner_kind), do: {:ok, nil}
  defp optional_worker(_company_id, "", _runner_kind), do: {:ok, nil}

  defp optional_worker(company_id, worker_id, runner_kind) do
    case AgentRegistry.get_worker(company_id, worker_id) do
      %AgentWorker{} = worker -> validate_worker_for_runner(worker, runner_kind)
      nil -> {:error, {:not_found, "Worker not found"}}
    end
  end

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

  defp ensure_run_can_start(%AgentWorker{execution_surface: "local_bridge"}, _runner_kind),
    do: :ok

  defp ensure_run_can_start(_worker, runner_kind) when runner_kind in @async_runner_kinds,
    do: :ok

  defp ensure_run_can_start(nil, _runner_kind),
    do: {:error, {:bad_request, "Selected work needs an assigned worker"}}

  defp ensure_run_can_start(%AgentWorker{}, _runner_kind),
    do: {:error, {:bad_request, "Selected work cannot start yet"}}

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

  defp after_run_created(
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

  defp after_run_created(_worker, %WorkRun{runner_kind: runner_kind} = run)
       when runner_kind in @async_runner_kinds do
    case WorkRuns.enqueue_start(run) do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp after_run_created(_worker, _run),
    do: {:error, {:bad_request, "Selected work cannot start yet"}}

  defp create_worker_profile(company_id, params) do
    AgentRegistry.create_agent_profile(%{
      company_id: company_id,
      name: display_name(params),
      agent_kind: Map.get(params, "agent_kind"),
      default_runner_kind: Map.get(params, "runner_kind"),
      default_visibility: "operator",
      capabilities: Map.get(params, "capabilities", []),
      public_description: "Connected worker"
    })
  end

  defp create_worker_with_profile(company_id, params, conn) do
    Repo.transaction(fn ->
      with {:ok, profile} <- create_worker_profile(company_id, params),
           {:ok, worker} <- register_worker_for_profile(company_id, profile.id, params, conn) do
        {profile, worker}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, {profile, worker}} -> {:ok, profile, worker}
      {:error, reason} -> {:error, reason}
    end
  end

  defp register_worker_for_profile(company_id, profile_id, params, conn) do
    attrs =
      params
      |> Map.take([
        "agent_kind",
        "worker_role",
        "execution_surface",
        "runner_kind",
        "billing_mode",
        "trust_scope",
        "reported_usage_policy"
      ])
      |> Map.merge(%{
        "agent_profile_id" => profile_id,
        "name" => display_name(params),
        "capabilities" => Map.get(params, "capabilities", []),
        "connection_metadata" => %{"endpoint_url" => Map.get(params, "endpoint_url")},
        "siwa_subject" => conn.assigns[:current_agent_claims] || %{}
      })

    if Map.get(params, "agent_kind") == "openclaw" do
      AgentRegistry.register_openclaw_worker(
        company_id,
        attrs,
        conn.assigns[:current_agent_claims] || %{}
      )
    else
      AgentRegistry.register_worker(company_id, attrs, conn.assigns[:current_agent_claims] || %{})
    end
  end

  defp display_name(params) do
    case Map.get(params, "display_name") do
      name when is_binary(name) and name != "" ->
        name

      _other ->
        "#{Map.get(params, "agent_kind", "agent")} #{Map.get(params, "worker_role", "worker")}"
    end
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

  defp runtime_health_payload(_runtime) do
    %{available: false, status: "unavailable", metering_status: "unmetered"}
  end

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
