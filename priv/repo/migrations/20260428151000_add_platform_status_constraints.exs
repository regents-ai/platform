defmodule PlatformPhx.Repo.Migrations.AddPlatformStatusConstraints do
  use Ecto.Migration

  def up do
    create constraint(:platform_companies, :platform_companies_status_check,
             check: "status IN ('forming', 'published', 'failed')"
           )

    create constraint(:platform_agents, :platform_agents_status_check,
             check: "status IN ('forming', 'published', 'failed')"
           )

    create constraint(:platform_agents, :platform_agents_runtime_status_check,
             check:
               "runtime_status IN ('queued', 'forming', 'ready', 'failed', 'paused_for_credits', 'paused')"
           )

    create constraint(:platform_agents, :platform_agents_checkpoint_status_check,
             check: "checkpoint_status IN ('pending', 'ready', 'failed')"
           )

    create constraint(:platform_agents, :platform_agents_stripe_llm_billing_status_check,
             check:
               "stripe_llm_billing_status IN ('not_connected', 'checkout_open', 'active', 'past_due', 'paused')"
           )

    create constraint(:platform_agents, :platform_agents_sprite_metering_status_check,
             check: "sprite_metering_status IN ('trialing', 'paid', 'paused')"
           )

    create constraint(:platform_agents, :platform_agents_desired_runtime_state_check,
             check: "desired_runtime_state IN ('active', 'paused')"
           )

    create constraint(:platform_agents, :platform_agents_observed_runtime_state_check,
             check: "observed_runtime_state IN ('unknown', 'active', 'paused')"
           )

    create constraint(:platform_billing_accounts, :platform_billing_accounts_billing_status_check,
             check:
               "billing_status IN ('not_connected', 'checkout_open', 'active', 'past_due', 'paused')"
           )

    create constraint(:platform_agent_formations, :platform_agent_formations_status_check,
             check: "status IN ('queued', 'running', 'failed', 'succeeded')"
           )

    create constraint(:platform_agent_formations, :platform_agent_formations_current_step_check,
             check:
               "current_step IN ('reserve_claim', 'create_sprite', 'bootstrap_sprite', 'bootstrap_workspace', 'verify_runtime', 'activate_subdomain', 'finalize')"
           )

    create constraint(:runtime_profiles, :runtime_profiles_status_check,
             check: "status IN ('active', 'paused', 'retired')"
           )

    create constraint(:runtime_services, :runtime_services_status_check,
             check:
               "status IN ('active', 'paused', 'retired', 'unknown', 'starting', 'stopping', 'failed')"
           )

    create constraint(:runtime_checkpoints, :runtime_checkpoints_status_check,
             check: "status IN ('pending', 'ready', 'failed')"
           )

    create constraint(:runtime_checkpoints, :runtime_checkpoints_restore_status_check,
             check:
               "restore_status IS NULL OR restore_status IN ('pending', 'succeeded', 'failed')"
           )

    create constraint(:agent_profiles, :agent_profiles_status_check,
             check: "status IN ('active', 'paused', 'retired')"
           )

    create constraint(:agent_workers, :agent_workers_status_check,
             check: "status IN ('registered', 'active', 'offline', 'revoked')"
           )

    create constraint(:agent_relationships, :agent_relationships_status_check,
             check: "status IN ('active', 'paused', 'revoked')"
           )

    create constraint(:budget_policies, :budget_policies_status_check,
             check: "status IN ('active', 'paused', 'retired')"
           )

    create constraint(:work_goals, :work_goals_status_check,
             check: "status IN ('draft', 'active', 'paused', 'completed', 'canceled')"
           )

    create constraint(:work_items, :work_items_status_check,
             check: "status IN ('draft', 'ready', 'running', 'blocked', 'completed', 'canceled')"
           )

    create constraint(:work_runs, :work_runs_status_check,
             check:
               "status IN ('queued', 'running', 'waiting_for_approval', 'completed', 'failed', 'canceled')"
           )

    create constraint(:approval_requests, :approval_requests_status_check,
             check: "status IN ('pending', 'approved', 'denied', 'expired', 'canceled')"
           )

    create constraint(:worker_assignments, :worker_assignments_status_check,
             check: "status IN ('available', 'leased', 'claimed', 'released', 'completed')"
           )

    create constraint(:platform_sprite_usage_records, :platform_sprite_usage_records_status_check,
             check: "status IN ('pending', 'reported', 'failed')"
           )

    create constraint(
             :platform_billing_ledger_entries,
             :platform_billing_ledger_entries_entry_type_check,
             check:
               "entry_type IN ('topup', 'runtime_debit', 'trial_grant', 'welcome_credit', 'manual_adjustment')"
           )

    create constraint(
             :platform_billing_ledger_entries,
             :platform_billing_ledger_entries_stripe_sync_status_check,
             check: "stripe_sync_status IN ('not_required', 'pending', 'synced', 'failed')"
           )
  end

  def down do
    raise "platform status constraints are a hard cutover"
  end
end
