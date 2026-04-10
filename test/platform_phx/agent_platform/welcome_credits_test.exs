defmodule PlatformPhx.AgentPlatform.WelcomeCreditsTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
  alias PlatformPhx.AgentPlatform.WelcomeCredits
  alias PlatformPhx.AgentPlatform.Workers.SyncWelcomeCreditGrantWorker
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)

    previous_credit_grant_result =
      Application.get_env(:platform_phx, :stripe_fake_credit_grant_result)

    previous_secret = System.get_env("STRIPE_SECRET_KEY")
    previous_enabled = System.get_env("WELCOME_CREDIT_ENABLED")
    previous_limit = System.get_env("WELCOME_CREDIT_LIMIT")
    previous_amount = System.get_env("WELCOME_CREDIT_AMOUNT_USD_CENTS")
    previous_expiry = System.get_env("WELCOME_CREDIT_EXPIRY_DAYS")

    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)
    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")
    System.put_env("WELCOME_CREDIT_ENABLED", "true")
    System.put_env("WELCOME_CREDIT_LIMIT", "100")
    System.put_env("WELCOME_CREDIT_AMOUNT_USD_CENTS", "500")
    System.put_env("WELCOME_CREDIT_EXPIRY_DAYS", "60")

    on_exit(fn ->
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)

      restore_app_env(
        :platform_phx,
        :stripe_fake_credit_grant_result,
        previous_credit_grant_result
      )

      restore_system_env("STRIPE_SECRET_KEY", previous_secret)
      restore_system_env("WELCOME_CREDIT_ENABLED", previous_enabled)
      restore_system_env("WELCOME_CREDIT_LIMIT", previous_limit)
      restore_system_env("WELCOME_CREDIT_AMOUNT_USD_CENTS", previous_amount)
      restore_system_env("WELCOME_CREDIT_EXPIRY_DAYS", previous_expiry)
    end)

    :ok
  end

  test "grants welcome credit once and stops after the configured limit" do
    System.put_env("WELCOME_CREDIT_LIMIT", "1")

    first_account = insert_billing_account!("privy-welcome-1", @address)

    second_account =
      insert_billing_account!("privy-welcome-2", "0x2222222222222222222222222222222222222222")

    assert {:ok, {:granted, _grant, updated_account}} = WelcomeCredits.maybe_grant(first_account)
    assert updated_account.runtime_credit_balance_usd_cents == 500

    assert {:ok, {:limit_reached, nil, ^second_account}} =
             WelcomeCredits.maybe_grant(second_account)

    assert Repo.aggregate(WelcomeCreditGrant, :count, :id) == 1
  end

  test "retry worker syncs a previously failed Stripe welcome credit grant" do
    account = insert_billing_account!("privy-welcome-retry", @address)

    assert {:ok, {:granted, grant, _updated_account}} = WelcomeCredits.maybe_grant(account)

    Application.put_env(
      :platform_phx,
      :stripe_fake_credit_grant_result,
      {:error, "Stripe credit grant unavailable"}
    )

    assert {:error, "Stripe credit grant unavailable"} =
             WelcomeCredits.sync_stripe_credit_grant(grant)

    failed_grant = Repo.get!(WelcomeCreditGrant, grant.id)
    assert failed_grant.stripe_sync_status == "failed"
    assert failed_grant.stripe_sync_attempt_count == 1

    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)

    assert :ok ==
             perform_job(SyncWelcomeCreditGrantWorker, %{
               "welcome_credit_grant_id" => grant.id
             })

    synced_grant = Repo.get!(WelcomeCreditGrant, grant.id)
    assert synced_grant.stripe_sync_status == "synced"
    assert synced_grant.stripe_credit_grant_id == "cg_test_runtime_credit"
    assert synced_grant.stripe_sync_attempt_count == 2
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
