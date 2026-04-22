defmodule PlatformPhx.AgentPlatform.SpriteAdminAction do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agent_sprite_admin_actions" do
    field :action, :string
    field :status, :string
    field :actor_type, :string
    field :source, :string
    field :message, :string
    field :details, :map, default: %{}

    belongs_to :agent, PlatformPhx.AgentPlatform.Agent
    belongs_to :human_user, PlatformPhx.Accounts.HumanUser
    belongs_to :formation, PlatformPhx.AgentPlatform.FormationRun

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(action, attrs) do
    action
    |> cast(attrs, [
      :agent_id,
      :human_user_id,
      :formation_id,
      :action,
      :status,
      :actor_type,
      :source,
      :message,
      :details
    ])
    |> validate_required([:agent_id, :action, :status, :actor_type, :source])
    |> validate_inclusion(:status, ["started", "succeeded", "failed"])
    |> validate_inclusion(:actor_type, ["human_user", "system"])
  end
end
