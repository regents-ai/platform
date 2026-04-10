defmodule PlatformPhx.Repo.Migrations.CutoverBillingAccountAndSpriteMetering do
  use Ecto.Migration

  def up do
    create table(:platform_billing_accounts) do
      add :human_user_id, references(:platform_human_users, on_delete: :delete_all), null: false
      add :stripe_customer_id, :string
      add :stripe_pricing_plan_subscription_id, :string
      add :billing_status, :string, null: false, default: "not_connected"
      add :runtime_credit_balance_usd_cents, :integer, null: false, default: 0

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:platform_billing_accounts, [:human_user_id])
    create unique_index(:platform_billing_accounts, [:stripe_customer_id])

    execute("""
    INSERT INTO platform_billing_accounts (
      human_user_id,
      stripe_customer_id,
      stripe_pricing_plan_subscription_id,
      billing_status,
      runtime_credit_balance_usd_cents,
      created_at,
      updated_at
    )
    SELECT
      human.id,
      NULLIF(human.stripe_customer_id, ''),
      NULLIF(human.stripe_pricing_plan_subscription_id, ''),
      CASE human.stripe_llm_billing_status
        WHEN 'checkout_open' THEN 'checkout_open'
        WHEN 'active' THEN 'active'
        WHEN 'past_due' THEN 'past_due'
        ELSE 'not_connected'
      END,
      COALESCE((
        SELECT SUM(COALESCE(agent.sprite_credit_balance_usd_cents, 0))
        FROM platform_agents agent
        WHERE agent.owner_human_id = human.id
      ), 0),
      NOW(),
      NOW()
    FROM platform_human_users human
    """)

    create table(:platform_billing_ledger_entries) do
      add :billing_account_id, references(:platform_billing_accounts, on_delete: :delete_all),
        null: false

      add :agent_id, references(:platform_agents, on_delete: :nilify_all)
      add :entry_type, :string, null: false
      add :amount_usd_cents, :integer, null: false
      add :description, :text
      add :source_ref, :string
      add :effective_at, :utc_datetime, null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:platform_billing_ledger_entries, [:billing_account_id, :effective_at])
    create unique_index(:platform_billing_ledger_entries, [:source_ref])

    create table(:platform_sprite_usage_records) do
      add :billing_account_id, references(:platform_billing_accounts, on_delete: :delete_all),
        null: false

      add :agent_id, references(:platform_agents, on_delete: :delete_all), null: false
      add :meter_key, :string, null: false
      add :usage_seconds, :integer, null: false, default: 0
      add :amount_usd_cents, :integer, null: false, default: 0
      add :window_started_at, :utc_datetime, null: false
      add :window_ended_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :stripe_meter_event_id, :string
      add :last_error_message, :text

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:platform_sprite_usage_records, [:billing_account_id, :window_ended_at])

    create unique_index(:platform_sprite_usage_records, [
             :agent_id,
             :window_started_at,
             :window_ended_at
           ])

    alter table(:platform_agents) do
      add :desired_runtime_state, :string, null: false, default: "active"
      add :observed_runtime_state, :string, null: false, default: "unknown"
    end

    execute("""
    UPDATE platform_agents
    SET desired_runtime_state = CASE
          WHEN runtime_status IN ('paused_for_credits', 'paused') THEN 'paused'
          ELSE 'active'
        END,
        observed_runtime_state = CASE
          WHEN runtime_status IN ('queued', 'forming', 'failed') THEN 'unknown'
          WHEN runtime_status IN ('paused_for_credits', 'paused') THEN 'paused'
          ELSE 'active'
        END
    """)

    create index(:platform_agents, [:desired_runtime_state])
    create index(:platform_agents, [:observed_runtime_state])
  end

  def down do
    drop index(:platform_agents, [:observed_runtime_state])
    drop index(:platform_agents, [:desired_runtime_state])

    alter table(:platform_agents) do
      remove :observed_runtime_state
      remove :desired_runtime_state
    end

    drop table(:platform_sprite_usage_records)
    drop table(:platform_billing_ledger_entries)
    drop table(:platform_billing_accounts)
  end
end
