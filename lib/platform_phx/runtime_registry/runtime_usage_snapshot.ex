defmodule PlatformPhx.RuntimeRegistry.RuntimeUsageSnapshot do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "runtime_usage_snapshots" do
    field :snapshot_at, :utc_datetime
    field :provider, :string, default: "sprites"
    field :compute_state, :string
    field :active_seconds, :integer, default: 0
    field :storage_bytes, :integer, default: 0
    field :estimated_cost_usd, :decimal, default: Decimal.new("0")
    field :reported_memory_mb, :integer
    field :reported_storage_bytes, :integer
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :runtime_profile, PlatformPhx.RuntimeRegistry.RuntimeProfile
    belongs_to :platform_sprite_usage_record, PlatformPhx.AgentPlatform.SpriteUsageRecord

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :company_id,
      :runtime_profile_id,
      :platform_sprite_usage_record_id,
      :snapshot_at,
      :provider,
      :compute_state,
      :active_seconds,
      :storage_bytes,
      :estimated_cost_usd,
      :reported_memory_mb,
      :reported_storage_bytes,
      :metadata
    ])
    |> validate_required([:company_id, :runtime_profile_id, :snapshot_at, :provider])
    |> validate_number(:active_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:storage_bytes, greater_than_or_equal_to: 0)
    |> validate_number(:reported_memory_mb, greater_than_or_equal_to: 0)
    |> validate_number(:reported_storage_bytes, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:runtime_profile_id)
    |> foreign_key_constraint(:platform_sprite_usage_record_id)
  end
end
