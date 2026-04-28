defmodule PlatformPhx.AgentRegistry.AgentProfile do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "agent_profiles" do
    field :name, :string
    field :agent_kind, :string
    field :status, :string, default: "active"
    field :default_runner_kind, :string
    field :default_visibility, :string, default: "operator"
    field :capabilities, {:array, :string}, default: []
    field :trust_level, :string, default: "delegated"
    field :memory_policy, :string, default: "summaries_only"
    field :public_description, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :created_by_human, PlatformPhx.Accounts.HumanUser

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :company_id,
      :created_by_human_id,
      :name,
      :agent_kind,
      :status,
      :default_runner_kind,
      :default_visibility,
      :capabilities,
      :trust_level,
      :memory_policy,
      :public_description,
      :metadata
    ])
    |> validate_required([:company_id, :name, :agent_kind, :status, :default_visibility])
    |> validate_inclusion(:agent_kind, RwrEnums.agent_kinds())
    |> validate_inclusion(:default_runner_kind, RwrEnums.runner_kinds())
    |> validate_inclusion(:default_visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:status, ["active", "paused", "retired"])
    |> validate_length(:name, max: 120)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:created_by_human_id)
    |> unique_constraint([:company_id, :name])
  end
end
