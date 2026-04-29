defmodule PlatformPhx.RunEvents.RunEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "run_events" do
    field :sequence, :integer
    field :kind, :string
    field :actor_kind, :string, default: "system"
    field :actor_id, :string
    field :visibility, :string, default: "operator"
    field :sensitivity, :string, default: "normal"
    field :payload, :map, default: %{}
    field :idempotency_key, :string
    field :occurred_at, :utc_datetime

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :run, PlatformPhx.WorkRuns.WorkRun

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :company_id,
      :run_id,
      :sequence,
      :kind,
      :actor_kind,
      :actor_id,
      :visibility,
      :sensitivity,
      :payload,
      :idempotency_key,
      :occurred_at
    ])
    |> put_default_occurred_at()
    |> validate_required([
      :company_id,
      :run_id,
      :sequence,
      :kind,
      :actor_kind,
      :visibility,
      :sensitivity,
      :occurred_at
    ])
    |> validate_number(:sequence, greater_than: 0)
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:sensitivity, ["normal", "sensitive", "secret"])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:run_id)
    |> unique_constraint([:run_id, :sequence])
    |> unique_constraint([:run_id, :idempotency_key])
  end

  defp put_default_occurred_at(changeset) do
    if get_field(changeset, :occurred_at) do
      changeset
    else
      put_change(changeset, :occurred_at, PlatformPhx.Clock.now())
    end
  end
end
