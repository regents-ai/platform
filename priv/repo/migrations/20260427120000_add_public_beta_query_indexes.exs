defmodule PlatformPhx.Repo.Migrations.AddPublicBetaQueryIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:platform_agents, [:owner_human_id, :updated_at],
                           name: :platform_agents_owner_updated_idx
                         )

    create_if_not_exists index(:platform_agents, [:status, :slug],
                           name: :platform_agents_status_slug_idx
                         )

    create_if_not_exists index(:basenames_mints, [:created_at],
                           name: :basenames_mints_created_at_idx
                         )

    create_if_not_exists index(
                           :platform_billing_ledger_entries,
                           [
                             :billing_account_id,
                             :stripe_sync_status,
                             :created_at
                           ],
                           name: :platform_billing_ledger_entries_sync_issue_idx
                         )

    create_if_not_exists index(
                           :platform_sprite_usage_records,
                           [
                             :billing_account_id,
                             :status,
                             :window_ended_at
                           ],
                           name: :platform_sprite_usage_records_status_window_idx
                         )
  end
end
