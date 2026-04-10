defmodule PlatformPhx.AgentPlatform.BillingAccount do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_billing_accounts" do
    field :stripe_customer_id, :string
    field :stripe_pricing_plan_subscription_id, :string
    field :billing_status, :string, default: "not_connected"
    field :runtime_credit_balance_usd_cents, :integer, default: 0

    belongs_to :human_user, PlatformPhx.Accounts.HumanUser
    has_many :ledger_entries, PlatformPhx.AgentPlatform.BillingLedgerEntry
    has_many :sprite_usage_records, PlatformPhx.AgentPlatform.SpriteUsageRecord
    has_many :welcome_credit_grants, PlatformPhx.AgentPlatform.WelcomeCreditGrant

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :human_user_id,
      :stripe_customer_id,
      :stripe_pricing_plan_subscription_id,
      :billing_status,
      :runtime_credit_balance_usd_cents
    ])
    |> validate_required([:human_user_id, :billing_status, :runtime_credit_balance_usd_cents])
    |> validate_inclusion(:billing_status, [
      "not_connected",
      "checkout_open",
      "active",
      "past_due",
      "paused"
    ])
    |> unique_constraint(:human_user_id)
    |> unique_constraint(:stripe_customer_id)
  end
end
