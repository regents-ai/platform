defmodule PlatformPhx.Runners.Codex.Events do
  @moduledoc false

  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns.WorkRun

  def append_client_events(%WorkRun{} = run, result, runner_id) when is_map(result) do
    result
    |> normalize_result_events()
    |> append_events(run, runner_id)
  end

  def append_run_event(%WorkRun{} = run, runner_id, kind, payload, key) do
    RunEvents.append_event(%{
      company_id: run.company_id,
      run_id: run.id,
      kind: kind,
      actor_kind: "system",
      visibility: "operator",
      sensitivity: "normal",
      payload: payload,
      idempotency_key: "#{runner_id}:#{run.id}:#{key}"
    })
  end

  def normalize_result_events(result) when is_map(result) do
    explicit_events =
      case attr(result, :events) do
        events when is_list(events) -> events
        nil -> []
        _events -> []
      end

    explicit_events ++ stream_events(result)
  end

  def stdout_event(output) when is_binary(output) and output != "" do
    %{
      kind: "codex.stdout",
      payload: %{stream: "stdout", output: output}
    }
  end

  def stdout_event(_output), do: nil

  def stderr_event(output) when is_binary(output) and output != "" do
    %{
      kind: "codex.stderr",
      payload: %{stream: "stderr", output: output},
      sensitivity: "normal"
    }
  end

  def stderr_event(_output), do: nil

  defp append_events(events, %WorkRun{} = run, runner_id) when is_list(events) do
    events
    |> Enum.reject(&is_nil/1)
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {event, index}, :ok ->
      case append_client_event(run, runner_id, event, index) do
        {:ok, _event} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp append_events(_events, _run, _runner_id), do: {:error, :invalid_codex_events}

  defp append_client_event(%WorkRun{} = run, runner_id, event, index) when is_map(event) do
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
          idempotency_key: "#{runner_id}:#{run.id}:client-event:#{index}"
        })

      _kind ->
        {:error, :invalid_codex_event}
    end
  end

  defp append_client_event(_run, _runner_id, _event, _index), do: {:error, :invalid_codex_event}

  defp stream_events(result) do
    [
      stdout_event(attr(result, :stdout)),
      stderr_event(attr(result, :stderr))
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
