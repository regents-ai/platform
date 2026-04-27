defmodule PlatformPhx.PublicBetaDatabaseTest do
  use PlatformPhx.DataCase, async: false

  @required_indexes [
    {"platform_agents", "platform_agents_owner_updated_idx"},
    {"platform_agents", "platform_agents_status_slug_idx"},
    {"basenames_mints", "basenames_mints_created_at_idx"},
    {"platform_billing_ledger_entries", "platform_billing_ledger_entries_sync_issue_idx"},
    {"platform_sprite_usage_records", "platform_sprite_usage_records_status_window_idx"}
  ]

  test "keeps indexes needed by public beta dashboard, company, billing, and name reads" do
    Enum.each(@required_indexes, fn {table, index} ->
      assert index_exists?(table, index)
    end)
  end

  defp index_exists?(table, index) do
    query = """
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = $1
      and indexname = $2
    """

    {:ok, %{num_rows: count}} = Repo.query(query, [table, index])
    count == 1
  end
end
