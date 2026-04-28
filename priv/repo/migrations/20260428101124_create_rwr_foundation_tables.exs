defmodule PlatformPhx.Repo.Migrations.CreateRwrFoundationTables do
  use Ecto.Migration

  def change do
    create table(:runtime_profiles) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :runner_kind, :text, null: false
      add :execution_surface, :text, null: false
      add :status, :text, null: false, default: "active"
      add :visibility, :text, null: false, default: "operator"
      add :config, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:runtime_profiles, [:company_id])
    create index(:runtime_profiles, [:runner_kind])
    create index(:runtime_profiles, [:execution_surface])
    create index(:runtime_profiles, [:status])
    create unique_index(:runtime_profiles, [:company_id, :name])

    create table(:runtime_services) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :runtime_profile_id, references(:runtime_profiles, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :service_kind, :text, null: false
      add :status, :text, null: false, default: "active"
      add :endpoint_url, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:runtime_services, [:company_id])
    create index(:runtime_services, [:runtime_profile_id])
    create index(:runtime_services, [:status])
    create unique_index(:runtime_services, [:runtime_profile_id, :name])

    create table(:agent_profiles) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :created_by_human_id, references(:platform_human_users, on_delete: :nilify_all)
      add :name, :text, null: false
      add :agent_kind, :text, null: false
      add :status, :text, null: false, default: "active"
      add :default_runner_kind, :text
      add :default_visibility, :text, null: false, default: "operator"
      add :capabilities, {:array, :text}, null: false, default: []
      add :trust_level, :text, null: false, default: "delegated"
      add :memory_policy, :text, null: false, default: "summaries_only"
      add :public_description, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:agent_profiles, [:company_id])
    create index(:agent_profiles, [:agent_kind])
    create index(:agent_profiles, [:status])
    create unique_index(:agent_profiles, [:company_id, :name])

    create table(:agent_workers) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :agent_profile_id, references(:agent_profiles, on_delete: :delete_all), null: false
      add :runtime_profile_id, references(:runtime_profiles, on_delete: :nilify_all)
      add :name, :text, null: false
      add :agent_kind, :text, null: false
      add :worker_role, :text, null: false
      add :execution_surface, :text, null: false
      add :runner_kind, :text, null: false
      add :billing_mode, :text, null: false
      add :trust_scope, :text, null: false
      add :reported_usage_policy, :text, null: false
      add :status, :text, null: false, default: "registered"
      add :last_heartbeat_at, :utc_datetime
      add :heartbeat_ttl_seconds, :integer, null: false, default: 60
      add :capabilities, {:array, :text}, null: false, default: []
      add :version, :text
      add :public_key, :text
      add :siwa_subject, :map, null: false, default: %{}
      add :connection_metadata, :map, null: false, default: %{}
      add :revoked_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:agent_workers, [:company_id])
    create index(:agent_workers, [:agent_profile_id])
    create index(:agent_workers, [:runtime_profile_id])
    create index(:agent_workers, [:status])
    create index(:agent_workers, [:runner_kind])
    create index(:agent_workers, [:last_heartbeat_at])
    create unique_index(:agent_workers, [:company_id, :name])

    create table(:agent_relationships) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :source_agent_profile_id, references(:agent_profiles, on_delete: :nilify_all)
      add :target_agent_profile_id, references(:agent_profiles, on_delete: :nilify_all)
      add :source_worker_id, references(:agent_workers, on_delete: :nilify_all)
      add :target_worker_id, references(:agent_workers, on_delete: :nilify_all)
      add :relationship_kind, :text, null: false
      add :status, :text, null: false, default: "active"
      add :routing_policy, :map, null: false, default: %{}
      add :max_parallel_runs, :integer, null: false, default: 1
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:agent_relationships, [:company_id])
    create index(:agent_relationships, [:source_agent_profile_id])
    create index(:agent_relationships, [:target_agent_profile_id])
    create index(:agent_relationships, [:source_worker_id])
    create index(:agent_relationships, [:target_worker_id])
    create index(:agent_relationships, [:relationship_kind])
    create index(:agent_relationships, [:status])

    create table(:budget_policies) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :scope_kind, :text, null: false
      add :scope_id, :integer
      add :status, :text, null: false, default: "active"
      add :max_cost_usd_per_run, :decimal, precision: 12, scale: 6
      add :max_cost_usd_per_day, :decimal, precision: 12, scale: 6
      add :max_runtime_minutes_per_run, :integer
      add :max_child_runs_per_root_run, :integer
      add :allow_set_and_forget, :boolean, null: false, default: true
      add :requires_approval_over_usd, :decimal, precision: 12, scale: 6
      add :protected_actions, {:array, :text}, null: false, default: []
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:budget_policies, [:company_id])
    create index(:budget_policies, [:scope_kind, :scope_id])
    create index(:budget_policies, [:status])

    create table(:work_goals) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :parent_goal_id, references(:work_goals, on_delete: :nilify_all)
      add :owner_agent_profile_id, references(:agent_profiles, on_delete: :nilify_all)
      add :budget_policy_id, references(:budget_policies, on_delete: :nilify_all)
      add :title, :text, null: false
      add :description, :text
      add :status, :text, null: false, default: "draft"
      add :priority, :text, null: false, default: "normal"
      add :visibility, :text, null: false, default: "operator"
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:work_goals, [:company_id])
    create index(:work_goals, [:parent_goal_id])
    create index(:work_goals, [:status])

    create table(:work_items) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :goal_id, references(:work_goals, on_delete: :nilify_all)
      add :assigned_agent_profile_id, references(:agent_profiles, on_delete: :nilify_all)
      add :assigned_worker_id, references(:agent_workers, on_delete: :nilify_all)
      add :budget_policy_id, references(:budget_policies, on_delete: :nilify_all)
      add :title, :text, null: false
      add :body, :text
      add :status, :text, null: false, default: "draft"
      add :priority, :text, null: false, default: "normal"
      add :visibility, :text, null: false, default: "operator"
      add :labels, {:array, :text}, null: false, default: []
      add :acceptance_criteria, {:array, :text}, null: false, default: []
      add :blocked_by, {:array, :integer}, null: false, default: []
      add :desired_runner_kind, :text
      add :workflow_spec_id, :integer
      add :source_kind, :text, null: false, default: "platform"
      add :source_ref, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:work_items, [:company_id])
    create index(:work_items, [:goal_id])
    create index(:work_items, [:status])
    create index(:work_items, [:assigned_agent_profile_id])
    create index(:work_items, [:assigned_worker_id])

    create table(:work_runs) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :work_item_id, references(:work_items, on_delete: :delete_all), null: false
      add :parent_run_id, references(:work_runs, on_delete: :nilify_all)
      add :root_run_id, references(:work_runs, on_delete: :nilify_all)
      add :delegated_by_run_id, references(:work_runs, on_delete: :nilify_all)
      add :worker_id, references(:agent_workers, on_delete: :nilify_all)
      add :runtime_profile_id, references(:runtime_profiles, on_delete: :nilify_all)
      add :runner_kind, :text, null: false
      add :workspace_path, :text
      add :status, :text, null: false, default: "queued"
      add :visibility, :text, null: false, default: "operator"
      add :attempt, :integer, null: false, default: 1
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :cost_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
      add :token_usage, :map, null: false, default: %{}
      add :input, :map, null: false, default: %{}
      add :summary, :text
      add :failure_reason, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:work_runs, [:company_id])
    create index(:work_runs, [:work_item_id])
    create index(:work_runs, [:parent_run_id])
    create index(:work_runs, [:root_run_id])
    create index(:work_runs, [:delegated_by_run_id])
    create index(:work_runs, [:worker_id])
    create index(:work_runs, [:runtime_profile_id])
    create index(:work_runs, [:status])

    create table(:runtime_checkpoints) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :runtime_profile_id, references(:runtime_profiles, on_delete: :delete_all), null: false
      add :work_run_id, references(:work_runs, on_delete: :nilify_all)
      add :checkpoint_ref, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :protected, :boolean, null: false, default: false
      add :captured_at, :utc_datetime
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:runtime_checkpoints, [:company_id])
    create index(:runtime_checkpoints, [:runtime_profile_id])
    create index(:runtime_checkpoints, [:work_run_id])
    create index(:runtime_checkpoints, [:status])
    create unique_index(:runtime_checkpoints, [:runtime_profile_id, :checkpoint_ref])

    create table(:run_events) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :run_id, references(:work_runs, on_delete: :delete_all), null: false
      add :sequence, :bigint, null: false
      add :kind, :text, null: false
      add :actor_kind, :text, null: false, default: "system"
      add :actor_id, :text
      add :visibility, :text, null: false, default: "operator"
      add :sensitivity, :text, null: false, default: "normal"
      add :payload, :map, null: false, default: %{}
      add :idempotency_key, :text
      add :occurred_at, :utc_datetime, null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create unique_index(:run_events, [:run_id, :sequence])

    create unique_index(:run_events, [:run_id, :idempotency_key],
             where: "idempotency_key IS NOT NULL"
           )

    create index(:run_events, [:company_id])
    create index(:run_events, [:kind])
    create index(:run_events, [:occurred_at])

    create table(:work_artifacts) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :work_item_id, references(:work_items, on_delete: :delete_all), null: false
      add :run_id, references(:work_runs, on_delete: :delete_all), null: false
      add :kind, :text, null: false
      add :title, :text
      add :uri, :text
      add :digest, :text
      add :visibility, :text, null: false, default: "operator"
      add :attestation_level, :text, null: false, default: "local_self_reported"
      add :content_inline, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:work_artifacts, [:company_id])
    create index(:work_artifacts, [:work_item_id])
    create index(:work_artifacts, [:run_id])
    create index(:work_artifacts, [:kind])
    create index(:work_artifacts, [:visibility])

    create table(:approval_requests) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :work_run_id, references(:work_runs, on_delete: :delete_all), null: false
      add :kind, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :requested_by_actor_kind, :text, null: false
      add :requested_by_actor_id, :text
      add :resolved_by_human_id, references(:platform_human_users, on_delete: :nilify_all)
      add :risk_summary, :text
      add :payload, :map, null: false, default: %{}
      add :resolved_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create index(:approval_requests, [:company_id])
    create index(:approval_requests, [:work_run_id])
    create index(:approval_requests, [:status])
    create index(:approval_requests, [:kind])

    create table(:runtime_usage_snapshots) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :runtime_profile_id, references(:runtime_profiles, on_delete: :delete_all), null: false
      add :snapshot_at, :utc_datetime, null: false
      add :provider, :text, null: false, default: "sprites"
      add :compute_state, :text
      add :active_seconds, :integer, null: false, default: 0
      add :storage_bytes, :bigint, null: false, default: 0
      add :estimated_cost_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:runtime_usage_snapshots, [:company_id])
    create index(:runtime_usage_snapshots, [:runtime_profile_id])
    create index(:runtime_usage_snapshots, [:snapshot_at])

    create table(:worker_assignments) do
      add :company_id, references(:platform_companies, on_delete: :delete_all), null: false
      add :worker_id, references(:agent_workers, on_delete: :delete_all), null: false
      add :work_run_id, references(:work_runs, on_delete: :delete_all), null: false
      add :status, :text, null: false, default: "available"
      add :leased_until, :utc_datetime
      add :claimed_at, :utc_datetime
      add :released_at, :utc_datetime
      add :metadata, :map, null: false, default: %{}

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:worker_assignments, [:work_run_id])
    create index(:worker_assignments, [:company_id])
    create index(:worker_assignments, [:worker_id])
    create index(:worker_assignments, [:status])
    create index(:worker_assignments, [:leased_until])
  end
end
