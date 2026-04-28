defmodule PlatformPhx.AgentRegistry.WorkerAssignment do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "worker_assignments" do
    field :status, :string, default: "available"
    field :leased_until, :utc_datetime
    field :claimed_at, :utc_datetime
    field :released_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :worker, PlatformPhx.AgentRegistry.AgentWorker
    belongs_to :work_run, PlatformPhx.WorkRuns.WorkRun

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :company_id,
      :worker_id,
      :work_run_id,
      :status,
      :leased_until,
      :claimed_at,
      :released_at,
      :metadata
    ])
    |> validate_required([:company_id, :worker_id, :work_run_id, :status])
    |> validate_inclusion(:status, ["available", "leased", "claimed", "released", "completed"])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:worker_id)
    |> foreign_key_constraint(:work_run_id)
    |> unique_constraint(:work_run_id)
  end
end
