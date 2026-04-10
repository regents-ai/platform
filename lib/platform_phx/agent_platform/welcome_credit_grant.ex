defmodule PlatformPhx.AgentPlatform.WelcomeCreditGrant do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_welcome_credit_grants" do
    field :grant_rank, :integer
    field :amount_usd_cents, :integer
    field :credit_scope, :string
    field :status, :string, default: "active"
    field :granted_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :stripe_credit_grant_id, :string
    field :stripe_sync_status, :string, default: "pending"
    field :stripe_sync_attempt_count, :integer, default: 0
    field :stripe_sync_last_error, :string
    field :stripe_synced_at, :utc_datetime
    field :source_ref, :string

    belongs_to :billing_account, PlatformPhx.AgentPlatform.BillingAccount
    belongs_to :human_user, PlatformPhx.Accounts.HumanUser

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :billing_account_id,
      :human_user_id,
      :grant_rank,
      :amount_usd_cents,
      :credit_scope,
      :status,
      :granted_at,
      :expires_at,
      :stripe_credit_grant_id,
      :stripe_sync_status,
      :stripe_sync_attempt_count,
      :stripe_sync_last_error,
      :stripe_synced_at,
      :source_ref
    ])
    |> validate_required([
      :billing_account_id,
      :human_user_id,
      :grant_rank,
      :amount_usd_cents,
      :credit_scope,
      :status,
      :granted_at,
      :expires_at,
      :stripe_sync_status,
      :source_ref
    ])
    |> validate_number(:grant_rank, greater_than: 0)
    |> validate_number(:amount_usd_cents, greater_than: 0)
    |> validate_number(:stripe_sync_attempt_count, greater_than_or_equal_to: 0)
    |> validate_inclusion(:credit_scope, ["runtime_only", "runtime_and_models"])
    |> validate_inclusion(:status, ["active", "expired", "revoked"])
    |> validate_inclusion(:stripe_sync_status, ["pending", "synced", "failed"])
    |> unique_constraint(:billing_account_id)
    |> unique_constraint(:human_user_id)
    |> unique_constraint(:grant_rank)
    |> unique_constraint(:source_ref)
  end
end
