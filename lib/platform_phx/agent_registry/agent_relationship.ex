defmodule PlatformPhx.AgentRegistry.AgentRelationship do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "agent_relationships" do
    field :relationship_kind, :string
    field :status, :string, default: "active"
    field :routing_policy, :map, default: %{}
    field :max_parallel_runs, :integer, default: 1
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :source_agent_profile, PlatformPhx.AgentRegistry.AgentProfile
    belongs_to :target_agent_profile, PlatformPhx.AgentRegistry.AgentProfile
    belongs_to :source_worker, PlatformPhx.AgentRegistry.AgentWorker
    belongs_to :target_worker, PlatformPhx.AgentRegistry.AgentWorker

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [
      :company_id,
      :source_agent_profile_id,
      :target_agent_profile_id,
      :source_worker_id,
      :target_worker_id,
      :relationship_kind,
      :status,
      :routing_policy,
      :max_parallel_runs,
      :metadata
    ])
    |> validate_required([:company_id, :relationship_kind, :status])
    |> validate_inclusion(:relationship_kind, RwrEnums.relationship_kinds())
    |> validate_inclusion(:status, RwrEnums.relationship_statuses())
    |> validate_number(:max_parallel_runs, greater_than: 0)
    |> validate_source()
    |> validate_target()
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:source_agent_profile_id)
    |> foreign_key_constraint(:target_agent_profile_id)
    |> foreign_key_constraint(:source_worker_id)
    |> foreign_key_constraint(:target_worker_id)
  end

  defp validate_source(changeset) do
    if get_field(changeset, :source_agent_profile_id) || get_field(changeset, :source_worker_id) do
      changeset
    else
      add_error(changeset, :source_agent_profile_id, "must include a source")
    end
  end

  defp validate_target(changeset) do
    if get_field(changeset, :target_agent_profile_id) || get_field(changeset, :target_worker_id) do
      changeset
    else
      add_error(changeset, :target_agent_profile_id, "must include a target")
    end
  end
end
