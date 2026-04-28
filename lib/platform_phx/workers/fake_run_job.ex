defmodule PlatformPhx.Workers.FakeRunJob do
  @moduledoc false

  use Oban.Worker,
    queue: :work_runs,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:run_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.Runners.Fake
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun

  @impl true
  def perform(%Job{args: %{"run_id" => run_id}}) do
    case WorkRuns.get_run(run_id) do
      nil ->
        {:cancel, "work run not found"}

      %WorkRun{runner_kind: "fake"} = run ->
        case Fake.run(run) do
          {:ok, _run} -> :ok
          {:error, reason} -> {:error, reason}
        end

      %WorkRun{} ->
        {:cancel, "work run is not fake"}
    end
  end
end
