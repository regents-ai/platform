defmodule PlatformPhx.Beta.StatusConstraintPreflight do
  @moduledoc false

  alias PlatformPhx.Repo

  @checks [
    {"platform_companies", "status", ~w(forming published failed)},
    {"platform_agents", "status", ~w(forming published failed)},
    {"platform_agents", "runtime_status",
     ~w(queued forming ready failed paused_for_credits paused)},
    {"platform_agents", "checkpoint_status", ~w(pending ready failed)},
    {"platform_agents", "stripe_llm_billing_status",
     ~w(not_connected checkout_open active past_due paused)},
    {"platform_agents", "sprite_metering_status", ~w(trialing paid paused)},
    {"platform_agents", "desired_runtime_state", ~w(active paused)},
    {"platform_agents", "observed_runtime_state", ~w(unknown active paused)},
    {"platform_billing_accounts", "billing_status",
     ~w(not_connected checkout_open active past_due paused)},
    {"platform_agent_formations", "status", ~w(queued running failed succeeded)},
    {"platform_agent_formations", "current_step",
     ~w(reserve_claim create_sprite bootstrap_sprite bootstrap_workspace verify_runtime activate_subdomain finalize)},
    {"runtime_profiles", "status", ~w(active paused retired)},
    {"runtime_services", "status", ~w(active paused retired unknown starting stopping failed)},
    {"runtime_checkpoints", "status", ~w(pending ready failed)},
    {"runtime_checkpoints", "restore_status", ~w(pending succeeded failed)},
    {"runtime_usage_snapshots", "compute_state", ~w(active paused retired)},
    {"agent_profiles", "status", ~w(active paused retired)},
    {"agent_workers", "status", ~w(registered active offline revoked)},
    {"agent_relationships", "status", ~w(active paused revoked)},
    {"budget_policies", "status", ~w(active paused retired)},
    {"work_goals", "status", ~w(draft active paused completed canceled)},
    {"work_items", "status", ~w(draft ready running blocked completed canceled)},
    {"work_runs", "status", ~w(queued running waiting_for_approval completed failed canceled)},
    {"approval_requests", "status", ~w(pending approved denied expired canceled)},
    {"worker_assignments", "status", ~w(available leased claimed released completed)},
    {"platform_sprite_usage_records", "status", ~w(pending reported failed)},
    {"platform_billing_ledger_entries", "entry_type",
     ~w(topup runtime_debit trial_grant welcome_credit manual_adjustment)},
    {"platform_billing_ledger_entries", "stripe_sync_status",
     ~w(not_required pending synced failed)},
    {"platform_stripe_events", "processing_status", ~w(queued processed)},
    {"agent_bug_reports", "status", ["pending", "fixed", "won't fix", "duplicate"]}
  ]

  def run(repo \\ Repo) do
    @checks
    |> Enum.reduce_while({:ok, []}, fn {table, column, allowed}, {:ok, issues} ->
      case invalid_values(repo, table, column, allowed) do
        {:ok, []} -> {:cont, {:ok, issues}}
        {:ok, rows} -> {:cont, {:ok, issues ++ [issue(table, column, rows)]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp invalid_values(repo, table, column, allowed) do
    repo.query(invalid_values_sql(table, column), [allowed])
    |> case do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &row_payload/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invalid_values_sql(table, column) do
    """
    select #{quote_identifier(column)}, count(*)::bigint
    from #{quote_identifier(table)}
    where #{quote_identifier(column)} is not null
      and not (#{quote_identifier(column)} = any($1::text[]))
    group by #{quote_identifier(column)}
    order by count(*) desc, #{quote_identifier(column)} asc
    limit 10
    """
  end

  defp quote_identifier(identifier) do
    "\"" <> String.replace(identifier, "\"", "\"\"") <> "\""
  end

  defp row_payload([value, count]), do: %{value: value, count: count}

  defp issue(table, column, rows) do
    %{table: table, column: column, invalid_values: rows}
  end
end
