defmodule PlatformPhx.Workers.StartWorkRunJob do
  @moduledoc false

  use Oban.Worker,
    queue: :work_runs,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:run_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.RunEvents
  alias PlatformPhx.Runners.Dispatcher
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun

  @impl true
  def perform(%Job{args: %{"run_id" => run_id}}) do
    case WorkRuns.get_run(run_id) do
      nil ->
        {:cancel, "work run not found"}

      %WorkRun{status: "completed"} ->
        :ok

      %WorkRun{status: status} when status != "queued" ->
        {:cancel, "work run is not queued"}

      %WorkRun{} = run ->
        dispatch(run)
    end
  end

  defp dispatch(%WorkRun{} = run) do
    case Dispatcher.dispatch(run) do
      {:ok, _job} ->
        :ok

      {:error, {:unsupported_runner_kind, runner_kind}} ->
        mark_unsupported(run, runner_kind)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mark_unsupported(%WorkRun{} = run, runner_kind) do
    reason = "unsupported runner kind: #{runner_kind}"

    with {:ok, _event} <-
           RunEvents.append_event(%{
             company_id: run.company_id,
             run_id: run.id,
             kind: "run.unsupported_runner",
             actor_kind: "system",
             visibility: "operator",
             sensitivity: "normal",
             payload: %{runner_kind: runner_kind},
             idempotency_key: "start-run:#{run.id}:unsupported-runner"
           }),
         {:ok, _run} <- WorkRuns.fail_run(run, reason) do
      :ok
    else
      {:error, failed_reason} -> {:error, failed_reason}
    end
  end
end
