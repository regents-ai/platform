defmodule PlatformPhx.Runners.Codex.Lifecycle do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.Runners.Codex.Events
  alias PlatformPhx.Runners.Codex.ProofArtifacts
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workflows
  alias PlatformPhx.Workspaces

  def run(%WorkRun{status: "completed"} = run, _opts), do: {:ok, run}
  def run(%WorkRun{status: "waiting_for_approval"} = run, _opts), do: {:ok, run}

  def run(%WorkRun{} = run, opts) do
    runner_id = Keyword.fetch!(opts, :runner_id)
    proof_source = Keyword.fetch!(opts, :proof_source)
    client = Keyword.fetch!(opts, :client)

    with {:ok, running_run} <- WorkRuns.mark_running(run),
         running_run <- Repo.preload(running_run, [:work_item, :runtime_profile], force: true),
         {:ok, workspace} <- Workspaces.prepare(running_run),
         {:ok, workflow} <- Workspaces.load_workflow(workspace),
         context <- Workflows.prompt_context(running_run, workspace),
         {:ok, prompt} <- Workflows.symphony_prompt(workflow, context),
         {:ok, workspace} <- Workspaces.write_prompt(workspace, prompt),
         {:ok, _event} <-
           Events.append_run_event(
             running_run,
             runner_id,
             "run.started",
             %{status: "running", workspace_path: workspace.path},
             "started"
           ) do
      %{
        run: running_run,
        workspace: workspace,
        workflow: workflow,
        prompt: prompt,
        context: context
      }
      |> client.run()
      |> handle_client_result(running_run, workspace, workflow, runner_id, proof_source)
    end
  end

  defp handle_client_result(
         {:ok, result},
         %WorkRun{} = run,
         workspace,
         workflow,
         runner_id,
         proof_source
       )
       when is_map(result) do
    with :ok <- Events.append_client_events(run, result, runner_id),
         {:ok, collected} <- Workspaces.collect(workspace),
         result <- Map.put(result, :collected_artifacts, collected),
         {:ok, artifact} <- ProofArtifacts.record(run, result, proof_source),
         {:ok, _event} <-
           Events.append_run_event(
             run,
             runner_id,
             "artifact.created",
             %{
               artifact_id: artifact.id,
               artifact_kind: artifact.kind,
               visibility: artifact.visibility
             },
             "artifact-created"
           ) do
      finish_run(run, result, workflow, runner_id)
    end
  end

  defp handle_client_result(
         {:error, reason},
         %WorkRun{} = run,
         _workspace,
         _workflow,
         runner_id,
         _proof_source
       ) do
    failure_reason = reason_to_string(reason)

    with {:ok, _event} <-
           Events.append_run_event(
             run,
             runner_id,
             "run.failed",
             %{status: "failed", reason: failure_reason},
             "failed"
           ),
         {:ok, failed_run} <- WorkRuns.fail_run(run, failure_reason) do
      {:ok, failed_run}
    end
  end

  defp handle_client_result(other, %WorkRun{} = run, workspace, workflow, runner_id, proof_source) do
    handle_client_result(
      {:error, {:invalid_client_result, other}},
      run,
      workspace,
      workflow,
      runner_id,
      proof_source
    )
  end

  defp finish_run(%WorkRun{} = run, result, workflow, runner_id) do
    if human_review_required?(result, workflow) do
      with {:ok, _event} <-
             Events.append_run_event(
               run,
               runner_id,
               "run.human_review",
               %{status: "human_review", summary: summary(result)},
               "human-review"
             ) do
        WorkRuns.request_human_review(run, %{
          summary: summary(result),
          metadata: Map.merge(run.metadata || %{}, %{"#{runner_id}_outcome" => "human_review"})
        })
      end
    else
      with {:ok, _event} <-
             Events.append_run_event(
               run,
               runner_id,
               "run.succeeded",
               %{status: "succeeded"},
               "succeeded"
             ) do
        WorkRuns.complete_run(run, %{
          summary: summary(result),
          metadata: Map.merge(run.metadata || %{}, %{"#{runner_id}_outcome" => "succeeded"})
        })
      end
    end
  end

  defp human_review_required?(result, workflow) do
    attr(result, :human_review_required) == true ||
      get_in(workflow, [:config, "review_required"]) == true
  end

  defp summary(result), do: attr(result, :summary) || "Codex run completed."

  defp reason_to_string(reason) when is_binary(reason), do: reason
  defp reason_to_string(reason), do: inspect(reason)

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
