defmodule PlatformPhx.Orchestration do
  @moduledoc false

  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.Security.Redactor
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun

  @async_runner_kinds ["codex_exec", "codex_app_server", "fake"]
  @local_bridge_surfaces ["local_bridge"]
  @runner_compatibility %{
    "codex_exec" => %{
      agent_kind: "codex",
      execution_surface: "hosted_sprite",
      runner_kinds: ["codex_exec", "codex_app_server"]
    },
    "codex_app_server" => %{
      agent_kind: "codex",
      execution_surface: "hosted_sprite",
      runner_kinds: ["codex_exec", "codex_app_server"]
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
    }
  }

  def handle_delegation_request(%WorkRun{} = parent_run, payload, actor_context) do
    payload = Map.new(payload)

    with :ok <- verify_parent_matches_payload(parent_run, payload),
         {:ok, parent_worker} <- parent_manager_worker(parent_run),
         :ok <- verify_actor_can_delegate(parent_run, parent_worker, actor_context),
         {:ok, tasks} <- delegation_tasks(payload),
         {:ok, worker} <- resolve_target_worker(parent_run.company_id, parent_worker, payload),
         :ok <- run_available_delegation_checks(parent_run, worker, payload, actor_context),
         {:ok, child_runs} <- create_child_runs(parent_run, worker, payload, tasks),
         :ok <- append_delegation_events(parent_run, payload, worker, child_runs, actor_context) do
      {:ok, %{target_worker: worker, child_runs: child_runs}}
    end
  end

  defp verify_parent_matches_payload(%WorkRun{} = parent_run, payload) do
    cond do
      present_attr(payload, :company_id) &&
          to_string(attr(payload, :company_id)) != to_string(parent_run.company_id) ->
        {:error, :company_mismatch}

      present_attr(payload, :run_id) &&
          to_string(attr(payload, :run_id)) != to_string(parent_run.id) ->
        {:error, :run_mismatch}

      is_nil(attr(payload, :requested_runner_kind)) ->
        {:error, :requested_runner_kind_required}

      true ->
        :ok
    end
  end

  defp parent_manager_worker(%WorkRun{} = parent_run) do
    parent_run = Repo.preload(parent_run, :worker)

    case parent_run.worker do
      %AgentWorker{worker_role: role} = worker when role in ["manager", "hybrid"] ->
        {:ok, worker}

      %AgentWorker{} ->
        {:error, :delegation_actor_not_allowed}

      nil ->
        {:error, :delegation_actor_not_allowed}
    end
  end

  defp verify_actor_can_delegate(parent_run, %AgentWorker{} = parent_worker, actor_context) do
    actor_context = Map.new(actor_context || %{})
    actor_worker_id = attr(actor_context, :worker_id)
    actor_agent_profile_id = attr(actor_context, :agent_profile_id)
    actor_company_id = attr(actor_context, :company_id)

    cond do
      present?(actor_company_id) &&
          to_string(actor_company_id) != to_string(parent_run.company_id) ->
        {:error, :delegation_actor_not_allowed}

      present?(actor_worker_id) && to_string(actor_worker_id) == to_string(parent_worker.id) ->
        :ok

      present?(actor_agent_profile_id) &&
          to_string(actor_agent_profile_id) == to_string(parent_worker.agent_profile_id) ->
        :ok

      true ->
        {:error, :delegation_actor_not_allowed}
    end
  end

  defp run_available_delegation_checks(parent_run, worker, payload, actor_context) do
    parent_run
    |> delegation_check_attrs(worker, payload, actor_context)
    |> PlatformPhx.Budgets.check_delegation_request()
    |> normalize_check_result()
  end

  defp delegation_check_attrs(parent_run, worker, payload, actor_context) do
    %{
      company_id: parent_run.company_id,
      work_run_id: parent_run.id,
      work_item_id: parent_run.work_item_id,
      root_run_id: parent_run.root_run_id || parent_run.id,
      worker_id: worker.id,
      billing_mode: worker.billing_mode,
      requested_by_actor_kind: attr(actor_context, :actor_kind) || "worker",
      requested_by_actor_id: actor_id(actor_context),
      requested_runner_kind: attr(payload, :requested_runner_kind),
      requested_child_run_count: length(attr(payload, :tasks) || []),
      tasks: attr(payload, :tasks),
      estimated_cost_usd: estimated_cost_usd(payload),
      estimated_runtime_minutes: attr(payload, :estimated_runtime_minutes),
      action: attr(payload, :action)
    }
  end

  defp estimated_cost_usd(payload) do
    case attr(payload, :budget_limit_usd_cents) do
      cents when is_integer(cents) -> Decimal.div(Decimal.new(cents), Decimal.new(100))
      _other -> attr(payload, :estimated_cost_usd) || Decimal.new("0")
    end
  end

  defp normalize_check_result(:ok), do: :ok
  defp normalize_check_result({:ok, _details}), do: :ok

  defp normalize_check_result({:approval_required, details}),
    do: {:error, {:approval_required, details}}

  defp normalize_check_result({:rejected, details}), do: {:error, {:delegation_rejected, details}}
  defp normalize_check_result({:error, reason}), do: {:error, reason}

  defp delegation_tasks(payload) do
    case attr(payload, :tasks) do
      tasks when is_list(tasks) and tasks != [] ->
        {:ok, Enum.map(tasks, &Map.new/1)}

      _other ->
        {:error, :delegation_tasks_required}
    end
  end

  defp resolve_target_worker(company_id, %AgentWorker{} = manager_worker, payload) do
    eligible_workers =
      company_id
      |> eligible_workers(manager_worker)
      |> filter_by_target_profile(attr(payload, :target_agent_profile_id))
      |> filter_by_requested_runner_kind(attr(payload, :requested_runner_kind))
      |> filter_by_preferred_agent_kind(attr(payload, :preferred_agent_kind))
      |> filter_by_execution_surface(attr(payload, :execution_surface))

    case attr(payload, :target_worker_id) do
      nil ->
        first_eligible_worker(eligible_workers)

      "" ->
        first_eligible_worker(eligible_workers)

      target_worker_id ->
        case Enum.find(eligible_workers, &(to_string(&1.id) == to_string(target_worker_id))) do
          %AgentWorker{} = worker -> {:ok, worker}
          nil -> {:error, :target_worker_not_eligible}
        end
    end
  end

  defp eligible_workers(company_id, %AgentWorker{} = manager_worker) do
    [manager_worker.id, manager_worker.agent_profile_id]
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&AgentRegistry.eligible_execution_workers(company_id, &1, %{}))
    |> Enum.uniq_by(& &1.id)
  end

  defp first_eligible_worker([%AgentWorker{} = worker | _rest]), do: {:ok, worker}
  defp first_eligible_worker([]), do: {:error, :no_eligible_worker}

  defp filter_by_target_profile(workers, nil), do: workers
  defp filter_by_target_profile(workers, ""), do: workers

  defp filter_by_target_profile(workers, target_agent_profile_id) do
    Enum.filter(workers, &(to_string(&1.agent_profile_id) == to_string(target_agent_profile_id)))
  end

  defp filter_by_requested_runner_kind(workers, requested_runner_kind) do
    Enum.filter(workers, &runner_compatible?(&1, requested_runner_kind))
  end

  defp filter_by_preferred_agent_kind(workers, nil), do: workers
  defp filter_by_preferred_agent_kind(workers, ""), do: workers

  defp filter_by_preferred_agent_kind(workers, preferred_agent_kind) do
    Enum.filter(workers, &(&1.agent_kind == preferred_agent_kind))
  end

  defp filter_by_execution_surface(workers, nil), do: workers
  defp filter_by_execution_surface(workers, ""), do: workers
  defp filter_by_execution_surface(workers, "manager_decides"), do: workers

  defp filter_by_execution_surface(workers, execution_surface) do
    Enum.filter(workers, &(&1.execution_surface == execution_surface))
  end

  defp runner_compatible?(_worker, nil), do: false

  defp runner_compatible?(%AgentWorker{} = worker, requested_runner_kind) do
    case Map.fetch(@runner_compatibility, requested_runner_kind) do
      {:ok, compatibility} ->
        worker.agent_kind == compatibility.agent_kind and
          worker.execution_surface == compatibility.execution_surface and
          worker.runner_kind in compatibility.runner_kinds

      :error ->
        worker.runner_kind == requested_runner_kind
    end
  end

  defp create_child_runs(parent_run, worker, payload, tasks) do
    tasks
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {task, index}, {:ok, child_runs} ->
      case create_child_run(parent_run, worker, payload, task, index) do
        {:ok, child_run} -> {:cont, {:ok, [child_run | child_runs]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, child_runs} -> {:ok, Enum.reverse(child_runs)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_child_run(parent_run, worker, payload, task, index) do
    runner_kind = child_runner_kind(worker, attr(payload, :requested_runner_kind))
    task_metadata = attr(task, :metadata) || %{}

    with :ok <- ensure_child_run_can_start(worker, runner_kind),
         {:ok, item} <-
           Work.create_item(%{
             company_id: parent_run.company_id,
             assigned_agent_profile_id: worker.agent_profile_id,
             assigned_worker_id: worker.id,
             title: attr(task, :title),
             body: attr(task, :instructions) || attr(payload, :instructions),
             status: "ready",
             visibility: parent_run.visibility,
             desired_runner_kind: runner_kind,
             source_kind: "delegation",
             source_ref: "run:#{parent_run.id}",
             metadata: %{
               delegated_by_run_id: parent_run.id,
               delegation_strategy: attr(payload, :strategy),
               task_index: index,
               task_metadata: task_metadata
             }
           }),
         {:ok, run} <-
           WorkRuns.create_run(%{
             company_id: parent_run.company_id,
             work_item_id: item.id,
             parent_run_id: parent_run.id,
             root_run_id: parent_run.root_run_id || parent_run.id,
             delegated_by_run_id: parent_run.id,
             worker_id: worker.id,
             runtime_profile_id: worker.runtime_profile_id,
             runner_kind: runner_kind,
             visibility: parent_run.visibility,
             input: %{
               task: %{
                 title: attr(task, :title),
                 instructions: attr(task, :instructions),
                 metadata: task_metadata
               },
               delegation: %{
                 strategy: attr(payload, :strategy),
                 requested_runner_kind: attr(payload, :requested_runner_kind)
               }
             },
             metadata: %{
               delegated_by_run_id: parent_run.id,
               target_worker_id: worker.id,
               target_agent_profile_id: worker.agent_profile_id
             }
           }),
         {:ok, _assignment} <- maybe_assign_local_worker(worker, run),
         {:ok, _job} <- maybe_enqueue_async_run(run) do
      {:ok, run}
    end
  end

  defp child_runner_kind(%AgentWorker{} = worker, requested_runner_kind) do
    if runner_compatible?(worker, requested_runner_kind),
      do: requested_runner_kind,
      else: worker.runner_kind
  end

  defp maybe_assign_local_worker(
         %AgentWorker{execution_surface: surface} = worker,
         %WorkRun{} = run
       )
       when surface in @local_bridge_surfaces do
    AgentRegistry.create_worker_assignment(worker.company_id, worker.id, %{work_run_id: run.id})
  end

  defp maybe_assign_local_worker(_worker, _run), do: {:ok, nil}

  defp maybe_enqueue_async_run(%WorkRun{runner_kind: runner_kind} = run)
       when runner_kind in @async_runner_kinds do
    WorkRuns.enqueue_start(run)
  end

  defp maybe_enqueue_async_run(_run), do: {:ok, nil}

  defp ensure_child_run_can_start(%AgentWorker{execution_surface: surface}, _runner_kind)
       when surface in @local_bridge_surfaces,
       do: :ok

  defp ensure_child_run_can_start(_worker, runner_kind) when runner_kind in @async_runner_kinds,
    do: :ok

  defp ensure_child_run_can_start(_worker, runner_kind),
    do: {:error, {:unsupported_runner_kind, runner_kind}}

  defp append_delegation_events(parent_run, payload, worker, child_runs, actor_context) do
    with {:ok, _event} <-
           append_delegation_requested_event(parent_run, payload, worker, actor_context) do
      child_runs
      |> Enum.reduce_while(:ok, fn child_run, :ok ->
        case append_child_run_created_event(parent_run, child_run, worker, actor_context) do
          {:ok, _event} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp append_delegation_requested_event(parent_run, payload, worker, actor_context) do
    RunEvents.append_event(%{
      company_id: parent_run.company_id,
      run_id: parent_run.id,
      kind: "delegation_requested",
      actor_kind: attr(actor_context, :actor_kind) || "worker",
      actor_id: actor_id(actor_context),
      visibility: parent_run.visibility,
      sensitivity: "normal",
      payload:
        Redactor.redact_event_payload(%{
          requested_runner_kind: attr(payload, :requested_runner_kind),
          strategy: attr(payload, :strategy),
          task_count: length(attr(payload, :tasks) || []),
          target_worker_id: worker.id,
          target_agent_profile_id: worker.agent_profile_id,
          execution_surface: worker.execution_surface
        })
    })
  end

  defp append_child_run_created_event(parent_run, child_run, worker, actor_context) do
    RunEvents.append_event(%{
      company_id: parent_run.company_id,
      run_id: parent_run.id,
      kind: "delegation_child_run_created",
      actor_kind: attr(actor_context, :actor_kind) || "worker",
      actor_id: actor_id(actor_context),
      visibility: parent_run.visibility,
      sensitivity: "normal",
      payload:
        Redactor.redact_event_payload(%{
          child_run_id: child_run.id,
          target_worker_id: worker.id,
          target_agent_profile_id: worker.agent_profile_id,
          runner_kind: child_run.runner_kind
        })
    })
  end

  defp actor_id(actor_context) do
    case attr(actor_context || %{}, :worker_id) do
      nil -> attr(actor_context || %{}, :agent_profile_id)
      worker_id -> worker_id
    end
    |> to_string_or_nil()
  end

  defp attr(attrs, key) when is_map(attrs) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp attr(_attrs, _key), do: nil

  defp present_attr(attrs, key), do: present?(attr(attrs, key))
  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)
end
