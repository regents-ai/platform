defmodule PlatformPhx.Orchestration.ChildRunFanout do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns.WorkRun

  @terminal_statuses %{
    "completed" => "child_run.completed",
    "failed" => "child_run.failed"
  }

  def maybe_append(%WorkRun{parent_run_id: nil} = run), do: {:ok, run}

  def maybe_append(%WorkRun{status: status} = run) when is_map_key(@terminal_statuses, status) do
    run = Repo.preload(run, :parent_run)

    case run.parent_run do
      %WorkRun{} = parent_run ->
        append_parent_event(parent_run, run)

      nil ->
        {:ok, run}
    end
  end

  def maybe_append(%WorkRun{} = run), do: {:ok, run}

  defp append_parent_event(%WorkRun{} = parent_run, %WorkRun{} = child_run) do
    kind = Map.fetch!(@terminal_statuses, child_run.status)

    with {:ok, _event} <-
           RunEvents.append_event(%{
             company_id: parent_run.company_id,
             run_id: parent_run.id,
             kind: kind,
             actor_kind: "system",
             visibility: parent_run.visibility,
             sensitivity: "normal",
             payload: payload(parent_run, child_run),
             idempotency_key: "child-run-fanout:#{child_run.id}:#{child_run.status}"
           }) do
      {:ok, child_run}
    end
  end

  defp payload(%WorkRun{} = parent_run, %WorkRun{} = child_run) do
    %{
      root_run_id: child_run.root_run_id || parent_run.root_run_id || parent_run.id,
      parent_run_id: parent_run.id,
      child_run_id: child_run.id,
      child_status: child_run.status,
      runner_kind: child_run.runner_kind,
      worker_id: child_run.worker_id,
      summary: child_run.summary,
      failure_reason: child_run.failure_reason
    }
  end
end
