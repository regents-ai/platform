defmodule PlatformPhx.AgentPlatform.FormationRun do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.AgentPlatform.FormationEvent

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agent_formations" do
    field :claimed_label, :string
    field :status, :string, default: "queued"
    field :current_step, :string, default: "reserve_claim"
    field :attempt_count, :integer, default: 0
    field :last_error_step, :string
    field :last_error_message, :string
    field :sprite_command_log_path, :string
    field :bootstrap_script_version, :string
    field :metadata, :map, default: %{}
    field :started_at, :utc_datetime
    field :last_heartbeat_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :agent, PlatformPhx.AgentPlatform.Agent
    belongs_to :human_user, PlatformPhx.Accounts.HumanUser
    has_many :events, FormationEvent, foreign_key: :formation_id

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(formation, attrs) do
    formation
    |> cast(attrs, [
      :agent_id,
      :human_user_id,
      :claimed_label,
      :status,
      :current_step,
      :attempt_count,
      :last_error_step,
      :last_error_message,
      :sprite_command_log_path,
      :bootstrap_script_version,
      :metadata,
      :started_at,
      :last_heartbeat_at,
      :completed_at
    ])
    |> validate_required([:agent_id, :human_user_id, :claimed_label, :status, :current_step])
    |> validate_inclusion(:status, ["queued", "running", "failed", "succeeded"])
    |> validate_inclusion(:current_step, [
      "reserve_claim",
      "create_sprite",
      "bootstrap_sprite",
      "bootstrap_paperclip",
      "create_company",
      "create_hermes",
      "create_checkpoint",
      "activate_subdomain",
      "finalize"
    ])
    |> unique_constraint(:agent_id)
  end
end
