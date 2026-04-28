defmodule PlatformPhx.Runners.CodexExec do
  @moduledoc false

  alias PlatformPhx.ProofPackets
  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workflows
  alias PlatformPhx.Workspaces

  @artifact_kind "proof_packet"

  def run(%WorkRun{status: "completed"} = run), do: {:ok, run}
  def run(%WorkRun{status: "waiting_for_approval"} = run), do: {:ok, run}

  def run(%WorkRun{} = run) do
    with {:ok, running_run} <- WorkRuns.mark_running(run),
         running_run <- Repo.preload(running_run, [:work_item, :runtime_profile], force: true),
         {:ok, workspace} <- Workspaces.prepare(running_run),
         {:ok, workflow} <- Workspaces.load_workflow(workspace),
         context <- Workflows.prompt_context(running_run, workspace),
         {:ok, prompt} <- Workflows.symphony_prompt(workflow, context),
         {:ok, workspace} <- Workspaces.write_prompt(workspace, prompt),
         {:ok, _event} <-
           append(
             running_run,
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
      |> client().run()
      |> handle_client_result(running_run, workspace, workflow)
    end
  end

  defp handle_client_result({:ok, result}, %WorkRun{} = run, workspace, workflow)
       when is_map(result) do
    events = Map.get(result, :events) || Map.get(result, "events") || []

    with :ok <- append_client_events(run, events),
         {:ok, collected} <- Workspaces.collect(workspace),
         result <- Map.put(result, :collected_artifacts, collected),
         {:ok, artifact} <- record_artifact(run, result),
         {:ok, _event} <-
           append(
             run,
             "artifact.created",
             %{
               artifact_id: artifact.id,
               artifact_kind: artifact.kind,
               visibility: artifact.visibility
             },
             "artifact-created"
           ) do
      finish_run(run, result, workflow)
    end
  end

  defp handle_client_result({:error, reason}, %WorkRun{} = run, _workspace, _workflow) do
    failure_reason = reason_to_string(reason)

    with {:ok, _event} <-
           append(
             run,
             "run.failed",
             %{status: "failed", reason: failure_reason},
             "failed"
           ),
         {:ok, failed_run} <- WorkRuns.fail_run(run, failure_reason) do
      {:ok, failed_run}
    end
  end

  defp handle_client_result(other, %WorkRun{} = run, workspace, workflow) do
    handle_client_result({:error, {:invalid_client_result, other}}, run, workspace, workflow)
  end

  defp append_client_events(%WorkRun{} = run, events) when is_list(events) do
    events
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {event, index}, :ok ->
      case append_client_event(run, event, index) do
        {:ok, _event} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp append_client_events(_run, _events), do: {:error, :invalid_codex_events}

  defp append_client_event(%WorkRun{} = run, event, index) when is_map(event) do
    case attr(event, :kind) do
      kind when is_binary(kind) ->
        RunEvents.append_event(%{
          company_id: run.company_id,
          run_id: run.id,
          kind: kind,
          actor_kind: attr(event, :actor_kind) || "system",
          actor_id: attr(event, :actor_id),
          visibility: attr(event, :visibility),
          sensitivity: attr(event, :sensitivity),
          occurred_at: attr(event, :occurred_at),
          payload: attr(event, :payload) || %{},
          idempotency_key: "codex-exec:#{run.id}:client-event:#{index}"
        })

      _kind ->
        {:error, :invalid_codex_event}
    end
  end

  defp append_client_event(_run, _event, _index), do: {:error, :invalid_codex_event}

  defp append(%WorkRun{} = run, kind, payload, key) do
    RunEvents.append_event(%{
      company_id: run.company_id,
      run_id: run.id,
      kind: kind,
      actor_kind: "system",
      visibility: "operator",
      sensitivity: "normal",
      payload: payload,
      idempotency_key: "codex-exec:#{run.id}:#{key}"
    })
  end

  defp record_artifact(%WorkRun{} = run, result) do
    case WorkRuns.get_artifact_by_run_and_kind(run.id, @artifact_kind) do
      %WorkArtifact{} = artifact ->
        {:ok, artifact}

      nil ->
        ProofPackets.record_artifact(%{
          company_id: run.company_id,
          work_item_id: run.work_item_id,
          run_id: run.id,
          kind: @artifact_kind,
          title:
            Map.get(result, :proof_title) || Map.get(result, "proof_title") || "Codex run proof",
          visibility: "operator",
          attestation_level: "platform_observed",
          content_inline: proof_content(result),
          metadata: %{
            runner_kind: run.runner_kind,
            proof_source: "codex_exec",
            run_id: run.id,
            company_id: run.company_id,
            collected_artifacts: Map.get(result, :collected_artifacts, %{})
          }
        })
    end
  end

  defp proof_content(result) do
    proof =
      Map.get(result, :proof) ||
        Map.get(result, "proof") ||
        Map.get(result, :summary) ||
        Map.get(result, "summary") ||
        "Codex run completed."

    collected = Map.get(result, :collected_artifacts, %{})

    [
      proof,
      "",
      "Changed files:",
      format_changed_files(Map.get(collected, :changed_files, [])),
      "",
      "Patch:",
      Map.get(collected, :patch, ""),
      "",
      "Test output:",
      Map.get(collected, :test_output, "")
    ]
    |> Enum.join("\n")
    |> String.trim()
  end

  defp summary(result) do
    Map.get(result, :summary) || Map.get(result, "summary") || "Codex run completed."
  end

  defp finish_run(%WorkRun{} = run, result, workflow) do
    if human_review_required?(result, workflow) do
      with {:ok, _event} <-
             append(
               run,
               "run.human_review",
               %{status: "human_review", summary: summary(result)},
               "human-review"
             ) do
        WorkRuns.request_human_review(run, %{
          summary: summary(result),
          metadata: Map.merge(run.metadata || %{}, %{"codex_exec_outcome" => "human_review"})
        })
      end
    else
      with {:ok, _event} <- append(run, "run.succeeded", %{status: "succeeded"}, "succeeded") do
        WorkRuns.complete_run(run, %{
          summary: summary(result),
          metadata: Map.merge(run.metadata || %{}, %{"codex_exec_outcome" => "succeeded"})
        })
      end
    end
  end

  defp human_review_required?(result, workflow) do
    attr(result, :human_review_required) == true ||
      get_in(workflow, [:config, "review_required"]) == true
  end

  defp format_changed_files([]), do: "None reported."

  defp format_changed_files(files) do
    files
    |> Enum.map(&"- #{&1}")
    |> Enum.join("\n")
  end

  defp reason_to_string(reason) when is_binary(reason), do: reason
  defp reason_to_string(reason), do: inspect(reason)

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp client do
    Application.get_env(:platform_phx, :codex_exec_client, __MODULE__.SystemCommandClient)
  end
end

defmodule PlatformPhx.Runners.CodexExec.SystemCommandClient do
  @moduledoc false

  def run(%{workspace: workspace, prompt: prompt}) do
    case Application.get_env(:platform_phx, :codex_exec_command) do
      {command, args} when is_binary(command) and is_list(args) ->
        run_command(command, args, workspace.path, prompt)

      command when is_binary(command) ->
        run_command(command, [], workspace.path, prompt)

      _missing ->
        {:error, "Codex execution command is not configured"}
    end
  end

  defp run_command(command, args, workspace_path, prompt) do
    case System.cmd(command, args, cd: workspace_path, input: prompt, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok,
         %{
           events: [
             %{
               kind: "codex.output",
               payload: %{output: output}
             }
           ],
           proof: output,
           summary: "Codex finished the assigned work."
         }}

      {output, status} ->
        {:error, "Codex command failed with status #{status}: #{output}"}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end
