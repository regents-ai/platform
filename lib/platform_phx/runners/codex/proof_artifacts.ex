defmodule PlatformPhx.Runners.Codex.ProofArtifacts do
  @moduledoc false

  alias PlatformPhx.ProofPackets
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkArtifact
  alias PlatformPhx.WorkRuns.WorkRun

  @artifact_kind "proof_packet"

  def record(%WorkRun{} = run, result, proof_source) do
    case WorkRuns.get_artifact_by_run_and_kind(run.id, @artifact_kind) do
      %WorkArtifact{} = artifact ->
        {:ok, artifact}

      nil ->
        ProofPackets.record_artifact(%{
          company_id: run.company_id,
          work_item_id: run.work_item_id,
          run_id: run.id,
          kind: @artifact_kind,
          title: attr(result, :proof_title) || "Codex run proof",
          visibility: "operator",
          attestation_level: "platform_observed",
          content_inline: proof_content(result),
          metadata: %{
            "runner_kind" => run.runner_kind,
            "proof_source" => proof_source,
            "run_id" => run.id,
            "company_id" => run.company_id,
            "collected_artifacts" => attr(result, :collected_artifacts) || %{}
          }
        })
    end
  end

  def proof_content(result) do
    proof =
      attr(result, :proof) ||
        attr(result, :summary) ||
        attr(result, :stdout) ||
        "Codex run completed."

    collected = attr(result, :collected_artifacts) || %{}

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

  defp format_changed_files([]), do: "None reported."

  defp format_changed_files(files) do
    files
    |> Enum.map(&"- #{&1}")
    |> Enum.join("\n")
  end

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
