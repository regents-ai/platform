defmodule PlatformPhx.RuntimeRegistry.RuntimeCheckpoint do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "runtime_checkpoints" do
    field :checkpoint_ref, :string
    field :status, :string, default: "pending"
    field :protected, :boolean, default: false
    field :checkpoint_kind, :string, default: "filesystem"
    field :captured_at, :utc_datetime
    field :restored_at, :utc_datetime
    field :restore_status, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :runtime_profile, PlatformPhx.RuntimeRegistry.RuntimeProfile
    belongs_to :work_run, PlatformPhx.WorkRuns.WorkRun

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [
      :company_id,
      :runtime_profile_id,
      :work_run_id,
      :checkpoint_ref,
      :status,
      :protected,
      :checkpoint_kind,
      :captured_at,
      :restored_at,
      :restore_status,
      :metadata
    ])
    |> validate_required([:company_id, :runtime_profile_id, :checkpoint_ref, :status])
    |> validate_inclusion(:status, ["pending", "ready", "failed"])
    |> validate_inclusion(:checkpoint_kind, ["filesystem"])
    |> validate_inclusion(:restore_status, ["pending", "succeeded", "failed"])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:runtime_profile_id)
    |> foreign_key_constraint(:work_run_id)
    |> unique_constraint([:runtime_profile_id, :checkpoint_ref])
  end
end
