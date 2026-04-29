defmodule PlatformPhx.AntiCruftTest do
  use ExUnit.Case, async: true

  test "production code does not build atoms from strings" do
    matches =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_number} ->
          String.contains?(line, "String.to_atom") or
            String.contains?(line, "String.to_existing_atom")
        end)
        |> Enum.map(fn {line, line_number} -> "#{path}:#{line_number}:#{line}" end)
      end)

    assert matches == []
  end

  test "web controllers do not access the database directly" do
    matches =
      grep("lib/platform_phx_web/controllers/**/*.ex", ["Repo.", "alias PlatformPhx.Repo"])

    assert matches == []
  end

  test "production code uses the shared external HTTP client instead of direct Req calls" do
    matches =
      "lib/platform_phx/**/*.ex"
      |> grep(["Req."])
      |> Enum.reject(&String.contains?(&1, "lib/platform_phx/external_http_client.ex"))

    assert matches == []
  end

  test "contract release artifacts are present and synchronized" do
    assert :ok = PlatformPhx.Contracts.validate_release_artifacts!()
    assert :ok = PlatformPhx.Contracts.validate_source_artifacts_match!()
  end

  test "hidden company creation trigger paths stay deleted" do
    matches =
      "lib/platform_phx/**/*.ex"
      |> grep(["prepare_changes", "platform_create_company_for_agent"])

    assert matches == []
  end

  test "runtime code uses the shared clock boundary" do
    matches =
      "lib/platform_phx/**/*.ex"
      |> grep(["DateTime.utc_now()", "System.system_time(:second)"])
      |> Enum.reject(&String.contains?(&1, "lib/platform_phx/clock.ex"))

    assert matches == []
  end

  test "current status fields are protected by database constraints" do
    migration_text =
      "priv/repo/migrations/*.exs"
      |> Path.wildcard()
      |> Enum.map_join("\n", &File.read!/1)

    required_constraints = [
      "platform_companies_status_check",
      "platform_agents_status_check",
      "platform_agents_runtime_status_check",
      "platform_agents_checkpoint_status_check",
      "platform_agents_stripe_llm_billing_status_check",
      "platform_agent_formations_status_check",
      "platform_agent_formations_current_step_check",
      "runtime_profiles_status_check",
      "runtime_services_status_check",
      "runtime_checkpoints_status_check",
      "runtime_checkpoints_restore_status_check",
      "runtime_usage_snapshots_compute_state_check",
      "agent_profiles_status_check",
      "agent_workers_status_check",
      "agent_relationships_status_check",
      "budget_policies_status_check",
      "work_goals_status_check",
      "work_items_status_check",
      "work_runs_status_check",
      "approval_requests_status_check",
      "worker_assignments_status_check",
      "platform_sprite_usage_records_status_check",
      "platform_billing_ledger_entries_stripe_sync_status_check",
      "platform_stripe_events_processing_status_check",
      "agent_bug_reports_status_check"
    ]

    missing =
      Enum.reject(required_constraints, &String.contains?(migration_text, &1))

    assert missing == []
  end

  defp grep(glob, needles) do
    glob
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _line_number} ->
        Enum.any?(needles, &String.contains?(line, &1))
      end)
      |> Enum.map(fn {line, line_number} -> "#{path}:#{line_number}:#{line}" end)
    end)
  end
end
