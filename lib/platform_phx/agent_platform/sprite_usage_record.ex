defmodule PlatformPhx.AgentPlatform.SpriteUsageRecord do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_sprite_usage_records" do
    field :meter_key, :string
    field :usage_seconds, :integer, default: 0
    field :amount_usd_cents, :integer, default: 0
    field :window_started_at, :utc_datetime
    field :window_ended_at, :utc_datetime
    field :status, :string, default: "pending"
    field :stripe_meter_event_id, :string
    field :stripe_sync_attempt_count, :integer, default: 0
    field :stripe_reported_at, :utc_datetime
    field :last_error_message, :string

    belongs_to :billing_account, PlatformPhx.AgentPlatform.BillingAccount
    belongs_to :agent, PlatformPhx.AgentPlatform.Agent

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :billing_account_id,
      :agent_id,
      :meter_key,
      :usage_seconds,
      :amount_usd_cents,
      :window_started_at,
      :window_ended_at,
      :status,
      :stripe_meter_event_id,
      :stripe_sync_attempt_count,
      :stripe_reported_at,
      :last_error_message
    ])
    |> validate_required([
      :billing_account_id,
      :agent_id,
      :meter_key,
      :usage_seconds,
      :amount_usd_cents,
      :window_started_at,
      :window_ended_at,
      :status
    ])
    |> validate_number(:usage_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:amount_usd_cents, greater_than_or_equal_to: 0)
    |> validate_number(:stripe_sync_attempt_count, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["pending", "reported", "failed"])
    |> unique_constraint([:agent_id, :window_started_at, :window_ended_at])
  end
end
