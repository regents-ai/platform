defmodule Web.Repo.Migrations.CutAgentPlatformToAgentFormation do
  use Ecto.Migration

  def up do
    alter table(:platform_human_users) do
      add :stripe_customer_id, :string
      add :stripe_pricing_plan_subscription_id, :string
      modify :stripe_llm_billing_status, :string, null: false, default: "not_connected"
      remove :stripe_llm_external_ref
    end

    execute("""
    UPDATE platform_human_users
    SET stripe_llm_billing_status = CASE
      WHEN stripe_llm_billing_status = 'connected' THEN 'active'
      ELSE 'not_connected'
    END
    """)

    alter table(:platform_agents) do
      add :sprite_service_name, :string
      add :sprite_checkpoint_ref, :string
      add :sprite_created_at, :utc_datetime
      add :paperclip_deployment_mode, :string
      add :paperclip_http_port, :integer
      add :hermes_adapter_type, :string
      add :hermes_model, :string
      add :hermes_persist_session, :boolean, null: false, default: true
      add :hermes_toolsets, {:array, :string}, null: false, default: []
      add :hermes_runtime_plugins, {:array, :string}, null: false, default: []
      add :hermes_shared_skills, {:array, :string}, null: false, default: []
      add :runtime_last_checked_at, :utc_datetime
      add :last_formation_error, :text
      add :stripe_customer_id, :string
      add :stripe_pricing_plan_subscription_id, :string
      modify :status, :string, null: false, default: "forming"
      modify :runtime_status, :string, null: false, default: "queued"
      modify :checkpoint_status, :string, null: false, default: "pending"
      modify :stripe_llm_billing_status, :string, null: false, default: "not_connected"
      remove :stripe_llm_external_ref
    end

    execute("""
    UPDATE platform_agents
    SET status = CASE
          WHEN status = 'published' THEN 'published'
          ELSE 'forming'
        END,
        runtime_status = CASE
          WHEN runtime_status = 'ready' THEN 'ready'
          WHEN runtime_status = 'paused_for_credits' THEN 'paused_for_credits'
          ELSE 'forming'
        END,
        checkpoint_status = CASE
          WHEN checkpoint_status = 'ready' THEN 'ready'
          ELSE 'pending'
        END,
        stripe_llm_billing_status = CASE
          WHEN stripe_llm_billing_status = 'connected' THEN 'active'
          ELSE 'not_connected'
        END,
        sprite_service_name = COALESCE(sprite_service_name, 'paperclip'),
        sprite_created_at = COALESCE(sprite_created_at, published_at, created_at),
        paperclip_deployment_mode = COALESCE(paperclip_deployment_mode, 'authenticated'),
        paperclip_http_port = COALESCE(paperclip_http_port, 3100),
        hermes_adapter_type = COALESCE(hermes_adapter_type, 'hermes_local'),
        hermes_model = COALESCE(hermes_model, 'glm-5.1'),
        runtime_last_checked_at = COALESCE(runtime_last_checked_at, updated_at)
    """)

    create table(:platform_agent_formations) do
      add :agent_id, references(:platform_agents, on_delete: :delete_all), null: false
      add :human_user_id, references(:platform_human_users, on_delete: :delete_all), null: false
      add :claimed_label, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :current_step, :string, null: false, default: "reserve_claim"
      add :attempt_count, :integer, null: false, default: 0
      add :last_error_step, :string
      add :last_error_message, :text
      add :sprite_command_log_path, :string
      add :bootstrap_script_version, :string
      add :metadata, :map, null: false, default: %{}
      add :started_at, :utc_datetime
      add :last_heartbeat_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_agent_formations, [:agent_id])
    create index(:platform_agent_formations, [:human_user_id, :status])
    create index(:platform_agent_formations, [:status, :current_step])

    create table(:platform_agent_formation_events) do
      add :formation_id, references(:platform_agent_formations, on_delete: :delete_all),
        null: false

      add :step, :string, null: false
      add :status, :string, null: false
      add :message, :text
      add :external_ref, :string
      add :details, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:platform_agent_formation_events, [:formation_id, :created_at])

    create table(:platform_agent_credit_ledger) do
      add :agent_id, references(:platform_agents, on_delete: :delete_all), null: false
      add :entry_type, :string, null: false
      add :amount_usd_cents, :integer, null: false
      add :description, :text
      add :source_ref, :string
      add :effective_at, :utc_datetime, null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:platform_agent_credit_ledger, [:agent_id, :effective_at])

    create table(:platform_agent_llm_usage_events) do
      add :agent_id, references(:platform_agents, on_delete: :delete_all), null: false
      add :human_user_id, references(:platform_human_users, on_delete: :delete_all), null: false
      add :external_run_id, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :cached_tokens, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"
      add :stripe_meter_event_id, :string
      add :occurred_at, :utc_datetime, null: false
      add :last_error_message, :text

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_agent_llm_usage_events, [:external_run_id])
    create index(:platform_agent_llm_usage_events, [:status, :occurred_at])
  end

  def down do
    drop table(:platform_agent_llm_usage_events)
    drop table(:platform_agent_credit_ledger)
    drop table(:platform_agent_formation_events)
    drop table(:platform_agent_formations)

    alter table(:platform_agents) do
      add :stripe_llm_external_ref, :string
      remove :stripe_pricing_plan_subscription_id
      remove :stripe_customer_id
      remove :last_formation_error
      remove :runtime_last_checked_at
      remove :hermes_shared_skills
      remove :hermes_runtime_plugins
      remove :hermes_toolsets
      remove :hermes_persist_session
      remove :hermes_model
      remove :hermes_adapter_type
      remove :paperclip_http_port
      remove :paperclip_deployment_mode
      remove :sprite_created_at
      remove :sprite_checkpoint_ref
      remove :sprite_service_name
      modify :stripe_llm_billing_status, :string, null: false, default: "action_required"
      modify :checkpoint_status, :string, null: false, default: "ready"
      modify :runtime_status, :string, null: false, default: "ready"
      modify :status, :string, null: false, default: "published"
    end

    alter table(:platform_human_users) do
      add :stripe_llm_external_ref, :string
      remove :stripe_pricing_plan_subscription_id
      remove :stripe_customer_id
      modify :stripe_llm_billing_status, :string, null: false, default: "action_required"
    end
  end
end
