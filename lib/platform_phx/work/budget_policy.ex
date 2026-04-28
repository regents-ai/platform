defmodule PlatformPhx.Work.BudgetPolicy do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "budget_policies" do
    field :scope_kind, :string
    field :scope_id, :integer
    field :status, :string, default: "active"
    field :max_cost_usd_per_run, :decimal
    field :max_cost_usd_per_day, :decimal
    field :max_runtime_minutes_per_run, :integer
    field :max_child_runs_per_root_run, :integer
    field :allow_set_and_forget, :boolean, default: true
    field :requires_approval_over_usd, :decimal
    field :protected_actions, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :company_id,
      :scope_kind,
      :scope_id,
      :status,
      :max_cost_usd_per_run,
      :max_cost_usd_per_day,
      :max_runtime_minutes_per_run,
      :max_child_runs_per_root_run,
      :allow_set_and_forget,
      :requires_approval_over_usd,
      :protected_actions,
      :metadata
    ])
    |> validate_required([:company_id, :scope_kind, :status])
    |> validate_inclusion(:scope_kind, [
      "company",
      "agent_profile",
      "worker",
      "work_goal",
      "work_item"
    ])
    |> validate_inclusion(:status, ["active", "paused", "retired"])
    |> validate_number(:max_runtime_minutes_per_run, greater_than: 0)
    |> validate_number(:max_child_runs_per_root_run, greater_than: 0)
    |> foreign_key_constraint(:company_id)
  end
end
