defmodule PlatformPhx.AgentPlatform.FormationEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agent_formation_events" do
    field :step, :string
    field :status, :string
    field :message, :string
    field :external_ref, :string
    field :details, :map, default: %{}

    belongs_to :formation, PlatformPhx.AgentPlatform.FormationRun

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:formation_id, :step, :status, :message, :external_ref, :details])
    |> validate_required([:formation_id, :step, :status])
    |> validate_inclusion(:status, ["started", "succeeded", "failed"])
  end
end
