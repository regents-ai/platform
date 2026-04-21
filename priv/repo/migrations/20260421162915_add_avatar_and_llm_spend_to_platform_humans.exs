defmodule PlatformPhx.Repo.Migrations.AddAvatarAndLlmSpendToPlatformHumans do
  use Ecto.Migration

  def change do
    alter table(:platform_human_users) do
      add :avatar, :map
    end

    alter table(:platform_agent_llm_usage_events) do
      add :amount_usd_cents, :integer, null: false, default: 0
    end

    create index(:platform_agent_llm_usage_events, [:human_user_id, :agent_id, :occurred_at])
  end
end
