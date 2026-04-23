defmodule PlatformPhx.AgentPlatform.FormationProgress do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.FormationEvent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.Repo

  @spec topic(pos_integer()) :: String.t()
  def topic(formation_id) when is_integer(formation_id) and formation_id > 0 do
    "agent_formation:#{formation_id}"
  end

  @spec subscribe(pos_integer()) :: :ok | {:error, :invalid_formation_id}
  def subscribe(formation_id) when is_integer(formation_id) and formation_id > 0 do
    Phoenix.PubSub.subscribe(PlatformPhx.PubSub, topic(formation_id))
  end

  def subscribe(_formation_id), do: {:error, :invalid_formation_id}

  @spec insert_event!(FormationRun.t(), String.t(), String.t(), String.t()) :: FormationEvent.t()
  def insert_event!(%FormationRun{} = formation, step, status, message) do
    %FormationEvent{}
    |> FormationEvent.changeset(%{
      formation_id: formation.id,
      step: step,
      status: status,
      message: message
    })
    |> Repo.insert!()
  end

  @spec broadcast(FormationRun.t(), FormationEvent.t()) :: :ok
  def broadcast(%FormationRun{} = formation, %FormationEvent{} = event) do
    :telemetry.execute(
      [:platform_phx, :agent_formation, :progress],
      %{count: 1},
      %{step: event.step, status: event.status}
    )

    Phoenix.PubSub.broadcast(
      PlatformPhx.PubSub,
      topic(formation.id),
      {:formation_progress, payload(formation, event)}
    )
  end

  @spec payload(FormationRun.t(), FormationEvent.t()) :: map()
  def payload(%FormationRun{} = formation, %FormationEvent{} = event) do
    %{
      formation_id: formation.id,
      agent_id: formation.agent_id,
      claimed_label: formation.claimed_label,
      status: formation.status,
      current_step: formation.current_step,
      event: %{
        step: event.step,
        status: event.status,
        message: event.message,
        created_at: event.created_at && DateTime.to_iso8601(event.created_at)
      }
    }
  end
end
