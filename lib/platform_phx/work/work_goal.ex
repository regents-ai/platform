defmodule PlatformPhx.Work.WorkGoal do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "work_goals" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "draft"
    field :priority, :string, default: "normal"
    field :visibility, :string, default: "operator"
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :parent_goal, __MODULE__
    belongs_to :owner_agent_profile, PlatformPhx.AgentRegistry.AgentProfile
    belongs_to :budget_policy, PlatformPhx.Work.BudgetPolicy

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :company_id,
      :parent_goal_id,
      :owner_agent_profile_id,
      :budget_policy_id,
      :title,
      :description,
      :status,
      :priority,
      :visibility,
      :metadata
    ])
    |> validate_required([:company_id, :title, :status, :priority, :visibility])
    |> validate_inclusion(:status, ["draft", "active", "paused", "completed", "canceled"])
    |> validate_inclusion(:priority, ["low", "normal", "high", "urgent"])
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:parent_goal_id)
    |> foreign_key_constraint(:owner_agent_profile_id)
    |> foreign_key_constraint(:budget_policy_id)
  end
end
