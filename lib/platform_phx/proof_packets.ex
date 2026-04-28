defmodule PlatformPhx.ProofPackets do
  @moduledoc false

  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.Repo
  alias PlatformPhx.Security.Redactor
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.WorkRun

  @openclaw_local_runner_kinds [
    "openclaw_local_manager",
    "openclaw_local_executor",
    "openclaw_code_agent_local"
  ]
  @artifact_fields [
    :company_id,
    :work_item_id,
    :run_id,
    :kind,
    :title,
    :uri,
    :digest,
    :visibility,
    :attestation_level,
    :content_inline,
    :metadata,
    :runner_kind,
    :publish_action
  ]

  def record_artifact(attrs) do
    attrs
    |> normalize_artifact_attrs()
    |> apply_local_openclaw_defaults()
    |> require_explicit_public_publish()
    |> case do
      {:ok, safe_attrs} -> WorkRuns.create_artifact(safe_attrs)
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_local_openclaw_defaults(attrs) do
    if local_openclaw_artifact?(attrs) do
      attrs
      |> put_default(:visibility, "operator")
      |> put_default(:attestation_level, "local_self_reported")
      |> put_metadata_defaults(%{"sensitivity" => "sensitive"})
      |> redact_metadata()
      |> redact_content_inline()
    else
      attrs
      |> put_default(:visibility, "operator")
      |> put_default(:attestation_level, "local_self_reported")
      |> redact_metadata()
      |> redact_content_inline()
    end
  end

  defp require_explicit_public_publish(attrs) do
    if attr(attrs, :visibility) == "public" and attr(attrs, :publish_action) != "publish_artifact" do
      {:error, :explicit_publish_action_required}
    else
      {:ok, attrs}
    end
  end

  defp local_openclaw_artifact?(attrs) do
    attr(attrs, :runner_kind) in @openclaw_local_runner_kinds or
      metadata_value(attrs, "runner_kind") in @openclaw_local_runner_kinds or
      metadata_value(attrs, "agent_kind") == "openclaw" or
      local_openclaw_run?(attr(attrs, :run_id))
  end

  defp local_openclaw_run?(nil), do: false

  defp local_openclaw_run?(run_id) do
    case Repo.get(WorkRun, run_id) |> Repo.preload(:worker) do
      %WorkRun{runner_kind: runner_kind} when runner_kind in @openclaw_local_runner_kinds ->
        true

      %WorkRun{worker: %AgentWorker{agent_kind: "openclaw", billing_mode: "user_local"}} ->
        true

      _run ->
        false
    end
  end

  defp put_default(attrs, key, value) do
    if is_nil(attr(attrs, key)), do: Map.put(attrs, key, value), else: attrs
  end

  defp put_metadata_defaults(attrs, defaults) do
    metadata = attr(attrs, :metadata) || %{}
    Map.put(attrs, :metadata, Map.merge(defaults, metadata))
  end

  defp redact_metadata(attrs) do
    metadata = attr(attrs, :metadata) || %{}
    Map.put(attrs, :metadata, Redactor.redact_event_payload(metadata))
  end

  defp redact_content_inline(attrs) do
    case attr(attrs, :content_inline) do
      content when is_binary(content) ->
        redacted =
          Redactor.redact_event_payload(%{
            "content_inline" => content
          })
          |> Map.fetch!("content_inline")

        Map.put(attrs, :content_inline, redacted)

      _content ->
        attrs
    end
  end

  defp metadata_value(attrs, key) do
    attrs
    |> attr(:metadata)
    |> case do
      metadata when is_map(metadata) ->
        metadata
        |> Enum.find_value(fn {metadata_key, value} ->
          if to_string(metadata_key) == key, do: value
        end)

      _metadata ->
        nil
    end
  end

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp normalize_artifact_attrs(attrs) do
    attrs = Map.new(attrs)

    Enum.reduce(@artifact_fields, %{}, fn field, normalized ->
      string_field = Atom.to_string(field)

      cond do
        Map.has_key?(attrs, field) ->
          Map.put(normalized, field, Map.fetch!(attrs, field))

        Map.has_key?(attrs, string_field) ->
          Map.put(normalized, field, Map.fetch!(attrs, string_field))

        true ->
          normalized
      end
    end)
  end
end
