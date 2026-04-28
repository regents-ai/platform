defmodule PlatformPhx.Repo.Migrations.ConnectRuntimeRegistryToSpriteUsage do
  use Ecto.Migration

  def change do
    alter table(:runtime_profiles) do
      add :platform_agent_id, references(:platform_agents, on_delete: :delete_all)
      add :billing_mode, :text, null: false, default: "user_local"
    end

    create index(:runtime_profiles, [:platform_agent_id])
    create index(:runtime_profiles, [:billing_mode])

    alter table(:runtime_usage_snapshots) do
      add :platform_sprite_usage_record_id,
          references(:platform_sprite_usage_records, on_delete: :nilify_all)
    end

    create index(:runtime_usage_snapshots, [:platform_sprite_usage_record_id],
             name: :runtime_usage_snapshots_sprite_usage_record_idx
           )
  end
end
