defmodule PlatformPhx.Work.WorkItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "work_items" do
    field :title, :string
    field :body, :string
    field :status, :string, default: "draft"
    field :priority, :string, default: "normal"
    field :visibility, :string, default: "operator"
    field :labels, {:array, :string}, default: []
    field :acceptance_criteria, {:array, :string}, default: []
    field :blocked_by, {:array, :integer}, default: []
    field :desired_runner_kind, :string
    field :workflow_spec_id, :integer
    field :source_kind, :string, default: "platform"
    field :source_ref, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :goal, PlatformPhx.Work.WorkGoal
    belongs_to :assigned_agent_profile, PlatformPhx.AgentRegistry.AgentProfile
    belongs_to :assigned_worker, PlatformPhx.AgentRegistry.AgentWorker
    belongs_to :budget_policy, PlatformPhx.Work.BudgetPolicy

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :company_id,
      :goal_id,
      :assigned_agent_profile_id,
      :assigned_worker_id,
      :budget_policy_id,
      :title,
      :body,
      :status,
      :priority,
      :visibility,
      :labels,
      :acceptance_criteria,
      :blocked_by,
      :desired_runner_kind,
      :workflow_spec_id,
      :source_kind,
      :source_ref,
      :metadata
    ])
    |> validate_required([:company_id, :title, :status, :priority, :visibility, :source_kind])
    |> validate_inclusion(:status, [
      "draft",
      "ready",
      "running",
      "blocked",
      "completed",
      "canceled"
    ])
    |> validate_inclusion(:priority, ["normal", "urgent"])
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:desired_runner_kind, RwrEnums.runner_kinds())
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:assigned_agent_profile_id)
    |> foreign_key_constraint(:assigned_worker_id)
    |> foreign_key_constraint(:budget_policy_id)
  end
end
