defmodule PlatformPhx.WorkRuns.WorkRun do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "work_runs" do
    field :runner_kind, :string
    field :workspace_path, :string
    field :status, :string, default: "queued"
    field :visibility, :string, default: "operator"
    field :attempt, :integer, default: 1
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :cost_usd, :decimal, default: Decimal.new("0")
    field :token_usage, :map, default: %{}
    field :input, :map, default: %{}
    field :summary, :string
    field :failure_reason, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :work_item, PlatformPhx.Work.WorkItem
    belongs_to :parent_run, __MODULE__
    belongs_to :root_run, __MODULE__
    belongs_to :delegated_by_run, __MODULE__
    belongs_to :worker, PlatformPhx.AgentRegistry.AgentWorker
    belongs_to :runtime_profile, PlatformPhx.RuntimeRegistry.RuntimeProfile

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :company_id,
      :work_item_id,
      :parent_run_id,
      :root_run_id,
      :delegated_by_run_id,
      :worker_id,
      :runtime_profile_id,
      :runner_kind,
      :workspace_path,
      :status,
      :visibility,
      :attempt,
      :started_at,
      :completed_at,
      :cost_usd,
      :token_usage,
      :input,
      :summary,
      :failure_reason,
      :metadata
    ])
    |> validate_required([
      :company_id,
      :work_item_id,
      :runner_kind,
      :status,
      :visibility,
      :attempt
    ])
    |> validate_inclusion(:runner_kind, RwrEnums.runner_kinds())
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:status, [
      "queued",
      "running",
      "waiting_for_approval",
      "completed",
      "failed",
      "canceled"
    ])
    |> validate_number(:attempt, greater_than: 0)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:work_item_id)
    |> foreign_key_constraint(:parent_run_id)
    |> foreign_key_constraint(:root_run_id)
    |> foreign_key_constraint(:delegated_by_run_id)
    |> foreign_key_constraint(:worker_id)
    |> foreign_key_constraint(:runtime_profile_id)
  end
end
