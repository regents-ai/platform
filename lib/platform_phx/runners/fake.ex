defmodule PlatformPhx.Runners.Fake do
  @moduledoc false

  alias PlatformPhx.ProofPackets
  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun

  @artifact_kind "proof_packet"

  def run(%WorkRun{status: "completed"} = run), do: {:ok, run}

  def run(%WorkRun{} = run) do
    with {:ok, running_run} <- WorkRuns.mark_running(run),
         {:ok, _event} <- append(running_run, "run.started", %{status: "running"}),
         {:ok, _event} <-
           append(running_run, "run.message", %{
             message: "Fake runner recorded a local proof artifact."
           }),
         {:ok, artifact} <- record_artifact(running_run),
         {:ok, _event} <-
           append(running_run, "artifact.created", %{
             artifact_id: artifact.id,
             artifact_kind: artifact.kind,
             visibility: artifact.visibility
           }),
         {:ok, _event} <- append(running_run, "run.completed", %{status: "completed"}) do
      WorkRuns.complete_run(running_run, %{
        summary: "Fake run completed with a local proof artifact.",
        metadata: Map.merge(running_run.metadata || %{}, %{"fake_runner_completed" => true})
      })
    end
  end

  defp append(%WorkRun{} = run, kind, payload) do
    RunEvents.append_event(%{
      company_id: run.company_id,
      run_id: run.id,
      kind: kind,
      actor_kind: "system",
      visibility: "operator",
      sensitivity: "normal",
      payload: payload,
      idempotency_key: "fake-run:#{run.id}:#{kind}"
    })
  end

  defp record_artifact(%WorkRun{} = run) do
    case WorkRuns.get_artifact_by_run_and_kind(run.id, @artifact_kind) do
      %WorkArtifact{} = artifact ->
        {:ok, artifact}

      nil ->
        ProofPackets.record_artifact(%{
          company_id: run.company_id,
          work_item_id: run.work_item_id,
          run_id: run.id,
          kind: @artifact_kind,
          title: "Fake run proof",
          visibility: "operator",
          attestation_level: "platform_observed",
          content_inline: "Fake run completed inside Platform.",
          metadata: %{
            runner_kind: run.runner_kind,
            proof_source: "fake_runner",
            run_id: run.id,
            company_id: run.company_id
          }
        })
    end
  end
end
