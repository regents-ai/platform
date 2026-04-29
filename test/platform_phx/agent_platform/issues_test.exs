defmodule PlatformPhx.AgentPlatform.IssuesTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.Issues
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  test "collects billing, usage, formation, and runtime issues for a human" do
    human = insert_human!()
    account = insert_billing_account!(human)
    agent = insert_agent!(human, "issue-agent", "failed", "failed")
    insert_failed_formation!(human, agent)
    insert_failed_billing_entry!(account)
    insert_failed_usage_record!(account, agent)

    issues = Issues.for_human(human)

    assert Enum.any?(issues, &(&1.surface == "billing"))
    assert Enum.any?(issues, &(&1.surface == "usage"))
    assert Enum.any?(issues, &(&1.surface == "formation"))
    assert Enum.any?(issues, &(&1.surface == "runtime"))

    notices = Enum.map(issues, &Issues.to_notice/1)
    assert Enum.any?(notices, &String.contains?(&1.message, "needs attention"))
  end

  defp insert_human! do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: @address,
      wallet_addresses: [@address]
    })
    |> Repo.insert!()
  end

  defp insert_billing_account!(human) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      billing_status: "active",
      runtime_credit_balance_usd_cents: 900
    })
    |> Repo.insert!()
  end

  defp insert_agent!(human, slug, runtime_status, checkpoint_status) do
    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      company_id: insert_company!(human, slug).id,
      template_key: "start",
      name: "Issue Agent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "published",
      public_summary: "Issue test",
      runtime_status: runtime_status,
      checkpoint_status: checkpoint_status
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    %Company{}
    |> Company.changeset(%{
      owner_human_id: human.id,
      name: "Issue Agent",
      slug: slug,
      claimed_label: slug,
      status: "published",
      public_summary: "Issue test"
    })
    |> Repo.insert!()
  end

  defp insert_failed_formation!(human, agent) do
    %FormationRun{}
    |> FormationRun.changeset(%{
      agent_id: agent.id,
      human_user_id: human.id,
      claimed_label: agent.slug,
      status: "failed",
      current_step: "verify_runtime",
      last_error_step: "verify_runtime",
      last_error_message: "not ready"
    })
    |> Repo.insert!()
  end

  defp insert_failed_billing_entry!(account) do
    %BillingLedgerEntry{}
    |> BillingLedgerEntry.changeset(%{
      billing_account_id: account.id,
      entry_type: "topup",
      amount_usd_cents: 500,
      source_ref: "topup:#{System.unique_integer([:positive])}",
      effective_at: DateTime.utc_now() |> DateTime.truncate(:second),
      stripe_sync_status: "failed",
      stripe_sync_attempt_count: 1
    })
    |> Repo.insert!()
  end

  defp insert_failed_usage_record!(account, agent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpriteUsageRecord{}
    |> SpriteUsageRecord.changeset(%{
      billing_account_id: account.id,
      agent_id: agent.id,
      meter_key: "runtime",
      usage_seconds: 60,
      amount_usd_cents: 2,
      window_started_at: DateTime.add(now, -60, :second),
      window_ended_at: now,
      status: "failed",
      stripe_sync_attempt_count: 1,
      last_error_message: "meter unavailable"
    })
    |> Repo.insert!()
  end
end
