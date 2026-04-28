defmodule PlatformPhx.Repo.Migrations.ExtendRuntimeRegistryForSpritesRuntimeOperations do
  use Ecto.Migration

  def change do
    alter table(:runtime_profiles) do
      add :provider_runtime_id, :text
      add :observed_memory_mb, :integer
      add :observed_storage_bytes, :bigint
      add :observed_capacity_at, :utc_datetime
      add :rate_limit_upgrade_url, :text
    end

    create index(:runtime_profiles, [:provider_runtime_id])

    alter table(:runtime_services) do
      add :provider_service_id, :text
      add :status_observed_at, :utc_datetime
      add :log_cursor, :text
      add :last_log_excerpt, :text
    end

    alter table(:runtime_checkpoints) do
      add :checkpoint_kind, :text, null: false, default: "filesystem"
      add :restored_at, :utc_datetime
      add :restore_status, :text
    end

    create index(:runtime_checkpoints, [:restore_status])

    alter table(:runtime_usage_snapshots) do
      add :reported_memory_mb, :integer
      add :reported_storage_bytes, :bigint
    end
  end
end
