defmodule PlatformPhx.Repo.Migrations.AddStripeSyncStateToPlatformBillingAndUsage do
  use Ecto.Migration

  def change do
    alter table(:platform_billing_ledger_entries) do
      add :stripe_credit_grant_id, :string
      add :stripe_sync_status, :string, null: false, default: "not_required"
      add :stripe_sync_attempt_count, :integer, null: false, default: 0
      add :stripe_sync_last_error, :text
      add :stripe_synced_at, :utc_datetime
    end

    alter table(:platform_sprite_usage_records) do
      add :stripe_sync_attempt_count, :integer, null: false, default: 0
      add :stripe_reported_at, :utc_datetime
    end
  end
end
