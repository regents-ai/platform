defmodule PlatformPhx.AgentPlatform.LlmUsageEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agent_llm_usage_events" do
    field :external_run_id, :string
    field :provider, :string
    field :model, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cached_tokens, :integer, default: 0
    field :amount_usd_cents, :integer, default: 0
    field :status, :string, default: "pending"
    field :stripe_meter_event_id, :string
    field :occurred_at, :utc_datetime
    field :last_error_message, :string

    belongs_to :agent, PlatformPhx.AgentPlatform.Agent
    belongs_to :human_user, PlatformPhx.Accounts.HumanUser

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :agent_id,
      :human_user_id,
      :external_run_id,
      :provider,
      :model,
      :input_tokens,
      :output_tokens,
      :cached_tokens,
      :amount_usd_cents,
      :status,
      :stripe_meter_event_id,
      :occurred_at,
      :last_error_message
    ])
    |> validate_required([
      :agent_id,
      :human_user_id,
      :external_run_id,
      :provider,
      :model,
      :occurred_at,
      :amount_usd_cents
    ])
    |> validate_number(:amount_usd_cents, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["pending", "reported", "failed"])
    |> unique_constraint(:external_run_id)
  end
end
