defmodule PlatformPhx.Runners.Dispatcher do
  @moduledoc false

  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workers.CodexExecRunJob
  alias PlatformPhx.Workers.FakeRunJob
  alias Oban

  def dispatch(run, opts \\ [])

  def dispatch(%WorkRun{runner_kind: runner_kind} = run, opts)
      when runner_kind in ["codex_exec", "codex_app_server"] do
    oban_module = Keyword.get(opts, :oban_module, Oban)

    %{run_id: run.id}
    |> CodexExecRunJob.new()
    |> oban_module.insert()
  end

  def dispatch(%WorkRun{runner_kind: "fake"} = run, opts) do
    oban_module = Keyword.get(opts, :oban_module, Oban)

    %{run_id: run.id}
    |> FakeRunJob.new()
    |> oban_module.insert()
  end

  def dispatch(%WorkRun{} = run, _opts) do
    {:error, {:unsupported_runner_kind, run.runner_kind}}
  end
end
