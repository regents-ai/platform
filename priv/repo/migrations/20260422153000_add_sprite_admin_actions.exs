defmodule PlatformPhx.Repo.Migrations.AddSpriteAdminActions do
  use Ecto.Migration

  def change do
    create table(:platform_agent_sprite_admin_actions) do
      add :agent_id, references(:platform_agents, on_delete: :delete_all), null: false
      add :human_user_id, references(:platform_human_users, on_delete: :nilify_all)
      add :formation_id, references(:platform_agent_formations, on_delete: :nilify_all)
      add :action, :string, null: false
      add :status, :string, null: false
      add :actor_type, :string, null: false
      add :source, :string, null: false
      add :message, :string
      add :details, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:platform_agent_sprite_admin_actions, [:agent_id, :created_at])
    create index(:platform_agent_sprite_admin_actions, [:human_user_id, :created_at])
    create index(:platform_agent_sprite_admin_actions, [:formation_id, :created_at])
    create index(:platform_agent_sprite_admin_actions, [:action, :created_at])
  end
end
