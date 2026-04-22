defmodule PlatformPhx.AgentPlatform.SpriteAudit do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.SpriteAdminAction
  alias PlatformPhx.Repo

  @type actor_metadata :: %{
          optional(:actor_type) => String.t(),
          optional(:human_user_id) => integer(),
          optional(:source) => String.t()
        }

  @spec log(Agent.t(), String.t(), String.t(), actor_metadata(), String.t() | nil, map()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def log(%Agent{} = agent, action, status, actor_metadata, message \\ nil, details \\ %{}) do
    %SpriteAdminAction{}
    |> SpriteAdminAction.changeset(%{
      agent_id: agent.id,
      human_user_id: Map.get(actor_metadata, :human_user_id),
      action: action,
      status: status,
      actor_type: Map.get(actor_metadata, :actor_type, "system"),
      source: Map.get(actor_metadata, :source, "unknown"),
      message: message,
      details: details
    })
    |> Repo.insert()
  end

  @spec log_formation(
          Agent.t(),
          FormationRun.t(),
          String.t(),
          String.t(),
          actor_metadata(),
          String.t() | nil,
          map()
        ) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def log_formation(
        %Agent{} = agent,
        %FormationRun{} = formation,
        action,
        status,
        actor_metadata,
        message \\ nil,
        details \\ %{}
      ) do
    %SpriteAdminAction{}
    |> SpriteAdminAction.changeset(%{
      agent_id: agent.id,
      human_user_id: Map.get(actor_metadata, :human_user_id),
      formation_id: formation.id,
      action: action,
      status: status,
      actor_type: Map.get(actor_metadata, :actor_type, "system"),
      source: Map.get(actor_metadata, :source, "unknown"),
      message: message,
      details: details
    })
    |> Repo.insert()
  end
end
