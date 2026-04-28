defmodule PlatformPhx.WorkRuns.ApprovalRequest do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "approval_requests" do
    field :kind, :string
    field :status, :string, default: "pending"
    field :requested_by_actor_kind, :string
    field :requested_by_actor_id, :string
    field :risk_summary, :string
    field :payload, :map, default: %{}
    field :resolved_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :work_run, PlatformPhx.WorkRuns.WorkRun
    belongs_to :resolved_by_human, PlatformPhx.Accounts.HumanUser

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :company_id,
      :work_run_id,
      :kind,
      :status,
      :requested_by_actor_kind,
      :requested_by_actor_id,
      :resolved_by_human_id,
      :risk_summary,
      :payload,
      :resolved_at,
      :expires_at
    ])
    |> validate_required([:company_id, :work_run_id, :kind, :status, :requested_by_actor_kind])
    |> validate_inclusion(:status, ["pending", "approved", "denied", "expired", "canceled"])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:work_run_id)
    |> foreign_key_constraint(:resolved_by_human_id)
  end
end
