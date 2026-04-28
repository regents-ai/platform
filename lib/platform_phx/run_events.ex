defmodule PlatformPhx.RunEvents do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Repo
  alias PlatformPhx.RunEvents.RunEvent
  alias PlatformPhx.Security.Redactor
  alias PlatformPhx.WorkRuns.WorkRun

  @topic_prefix "rwr:run"
  @openclaw_local_runner_kinds [
    "openclaw_local_manager",
    "openclaw_local_executor",
    "openclaw_code_agent_local"
  ]
  @event_fields [
    :company_id,
    :run_id,
    :sequence,
    :kind,
    :actor_kind,
    :actor_id,
    :visibility,
    :sensitivity,
    :payload,
    :idempotency_key,
    :occurred_at
  ]

  def append_event(attrs) do
    attrs = normalize_event_attrs(attrs)

    case Repo.transaction(fn -> append_event_in_transaction(attrs) end) do
      {:ok, {:inserted, event}} ->
        :ok = broadcast_event(event)
        {:ok, event}

      {:ok, {:existing, event}} ->
        {:ok, event}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_events(run_id) do
    RunEvent
    |> where([event], event.run_id == ^run_id)
    |> order_by([event], asc: event.sequence)
    |> Repo.all()
  end

  def list_events(company_id, run_id) do
    RunEvent
    |> where([event], event.company_id == ^company_id and event.run_id == ^run_id)
    |> order_by([event], asc: event.sequence)
    |> Repo.all()
  end

  def replay_events(company_id, run_id), do: list_events(company_id, run_id)

  def topic(run_id), do: "#{@topic_prefix}:#{run_id}"

  def subscribe(run_id), do: Phoenix.PubSub.subscribe(PlatformPhx.PubSub, topic(run_id))

  def unsubscribe(run_id), do: Phoenix.PubSub.unsubscribe(PlatformPhx.PubSub, topic(run_id))

  defp append_event_in_transaction(attrs) do
    company_id = attr(attrs, :company_id)
    run_id = attr(attrs, :run_id)

    with %WorkRun{} = run <- lock_run(company_id, run_id) do
      case existing_event(run_id, attr(attrs, :idempotency_key)) do
        %RunEvent{} = event ->
          {:existing, event}

        nil ->
          attrs
          |> apply_safety_defaults(run)
          |> insert_next_event(run_id)
      end
    else
      nil -> Repo.rollback(:run_not_found)
    end
  end

  defp lock_run(company_id, run_id) do
    WorkRun
    |> where([run], run.company_id == ^company_id and run.id == ^run_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp existing_event(_run_id, nil), do: nil
  defp existing_event(_run_id, ""), do: nil

  defp existing_event(run_id, idempotency_key) do
    Repo.get_by(RunEvent, run_id: run_id, idempotency_key: idempotency_key)
  end

  defp insert_next_event(attrs, run_id) do
    next_sequence = next_sequence(run_id)
    explicit_sequence = attr(attrs, :sequence)

    if explicit_sequence in [nil, next_sequence] do
      attrs
      |> put_attr(:sequence, next_sequence)
      |> insert_event()
    else
      Repo.rollback({:sequence_mismatch, %{expected: next_sequence, received: explicit_sequence}})
    end
  end

  defp next_sequence(run_id) do
    RunEvent
    |> where([event], event.run_id == ^run_id)
    |> select([event], fragment("COALESCE(MAX(?), 0)", event.sequence))
    |> Repo.one()
    |> Kernel.+(1)
  end

  defp insert_event(attrs) do
    case %RunEvent{} |> RunEvent.changeset(attrs) |> Repo.insert() do
      {:ok, event} -> {:inserted, event}
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp apply_safety_defaults(attrs, %WorkRun{} = run) do
    attrs
    |> put_default(:visibility, "operator")
    |> put_default(:sensitivity, if(local_openclaw_run?(run), do: "sensitive", else: "normal"))
    |> put_attr(:payload, Redactor.redact_event_payload(attr(attrs, :payload) || %{}))
  end

  defp put_default(attrs, key, value) do
    if is_nil(attr(attrs, key)), do: put_attr(attrs, key, value), else: attrs
  end

  defp local_openclaw_run?(%WorkRun{runner_kind: runner_kind}) do
    runner_kind in @openclaw_local_runner_kinds
  end

  defp attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp put_attr(attrs, key, value) do
    Map.put(attrs, key, value)
  end

  defp broadcast_event(%RunEvent{} = event) do
    Phoenix.PubSub.broadcast(PlatformPhx.PubSub, topic(event.run_id), {:rwr_run_event, event})
  end

  defp normalize_event_attrs(attrs) do
    attrs = Map.new(attrs)

    Enum.reduce(@event_fields, %{}, fn field, normalized ->
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
