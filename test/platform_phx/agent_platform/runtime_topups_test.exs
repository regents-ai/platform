defmodule PlatformPhx.AgentPlatform.RuntimeTopupsTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.RuntimeTopups
  alias PlatformPhx.AgentPlatform.Workers.SyncTopupCreditGrantWorker
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)

    previous_credit_grant_result =
      Application.get_env(:platform_phx, :stripe_fake_credit_grant_result)

    previous_secret = System.get_env("STRIPE_SECRET_KEY")

    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)
    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")

    on_exit(fn ->
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)

      restore_app_env(
        :platform_phx,
        :stripe_fake_credit_grant_result,
        previous_credit_grant_result
      )

      restore_system_env("STRIPE_SECRET_KEY", previous_secret)
    end)

    :ok
  end

  test "retry worker syncs a previously failed Stripe top-up credit grant" do
    account = insert_billing_account!("privy-topup", @address)

    entry =
      %BillingLedgerEntry{}
      |> BillingLedgerEntry.changeset(%{
        billing_account_id: account.id,
        entry_type: "topup",
        amount_usd_cents: 800,
        description: "Runtime credit added through Stripe Checkout.",
        source_ref: "stripe-event:evt_test_topup_retry",
        effective_at: DateTime.utc_now() |> DateTime.truncate(:second),
        stripe_sync_status: "pending",
        stripe_sync_attempt_count: 0
      })
      |> Repo.insert!()

    Application.put_env(
      :platform_phx,
      :stripe_fake_credit_grant_result,
      {:error, "Stripe credit grant unavailable"}
    )

    assert {:error, "Stripe credit grant unavailable"} =
             RuntimeTopups.sync_credit_grant(entry)

    failed_entry = Repo.get!(BillingLedgerEntry, entry.id)
    assert failed_entry.stripe_sync_status == "failed"
    assert failed_entry.stripe_sync_attempt_count == 1

    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)

    assert :ok ==
             perform_job(SyncTopupCreditGrantWorker, %{
               "billing_ledger_entry_id" => entry.id
             })

    synced_entry = Repo.get!(BillingLedgerEntry, entry.id)
    assert synced_entry.stripe_sync_status == "synced"
    assert synced_entry.stripe_credit_grant_id == "cg_test_runtime_credit"
    assert synced_entry.stripe_sync_attempt_count == 2
    assert is_struct(synced_entry.stripe_synced_at, DateTime)
  end

  defp insert_billing_account!(privy_user_id, wallet_address) do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: privy_user_id,
        wallet_address: wallet_address,
        wallet_addresses: [wallet_address]
      })
      |> Repo.insert!()

    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      billing_status: "active",
      stripe_customer_id: "cus_#{privy_user_id}",
      stripe_pricing_plan_subscription_id: "sub_#{privy_user_id}",
      runtime_credit_balance_usd_cents: 0
    })
    |> Repo.insert!()
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
end
