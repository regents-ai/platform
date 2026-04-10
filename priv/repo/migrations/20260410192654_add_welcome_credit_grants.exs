defmodule PlatformPhx.Repo.Migrations.AddWelcomeCreditGrants do
  use Ecto.Migration

  def change do
    create table(:platform_promotion_counters) do
      add :promotion_key, :string, null: false
      add :next_rank, :integer, null: false, default: 1
      add :limit_count, :integer, null: false, default: 100

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_promotion_counters, [:promotion_key])

    create table(:platform_welcome_credit_grants) do
      add :billing_account_id, references(:platform_billing_accounts, on_delete: :delete_all),
        null: false

      add :human_user_id, references(:platform_human_users, on_delete: :delete_all), null: false
      add :grant_rank, :integer, null: false
      add :amount_usd_cents, :integer, null: false
      add :credit_scope, :string, null: false
      add :status, :string, null: false, default: "active"
      add :granted_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime, null: false
      add :stripe_credit_grant_id, :string
      add :stripe_sync_status, :string, null: false, default: "pending"
      add :stripe_sync_attempt_count, :integer, null: false, default: 0
      add :stripe_sync_last_error, :text
      add :stripe_synced_at, :utc_datetime
      add :source_ref, :string, null: false

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_welcome_credit_grants, [:billing_account_id])
    create unique_index(:platform_welcome_credit_grants, [:human_user_id])
    create unique_index(:platform_welcome_credit_grants, [:grant_rank])
    create unique_index(:platform_welcome_credit_grants, [:source_ref])
    create index(:platform_welcome_credit_grants, [:status, :expires_at])
  end
end
