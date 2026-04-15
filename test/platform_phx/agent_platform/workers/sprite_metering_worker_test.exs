defmodule PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorkerTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.Workers.SyncSpriteUsageRecordWorker
  alias PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorker
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)
    previous_sprite_runtime_client = Application.get_env(:platform_phx, :sprite_runtime_client)

    previous_runtime_usage_result =
      Application.get_env(:platform_phx, :stripe_fake_runtime_usage_result)

    previous_secret = System.get_env("STRIPE_SECRET_KEY")
    previous_runtime_meter_name = System.get_env("STRIPE_RUNTIME_METER_EVENT_NAME")

    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_runtime_usage_result, :ok)

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientFake
    )

    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")
    System.put_env("STRIPE_RUNTIME_METER_EVENT_NAME", "sprite_runtime_seconds")

    on_exit(fn ->
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)
      restore_app_env(:platform_phx, :sprite_runtime_client, previous_sprite_runtime_client)

      restore_app_env(
        :platform_phx,
        :stripe_fake_runtime_usage_result,
        previous_runtime_usage_result
      )

      restore_system_env("STRIPE_SECRET_KEY", previous_secret)
      restore_system_env("STRIPE_RUNTIME_METER_EVENT_NAME", previous_runtime_meter_name)
    end)

    :ok
  end

  test "meters a running sprite against the shared billing account and pauses at zero" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-meter",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: "cus_test_agent_formation",
        stripe_pricing_plan_subscription_id: "sub_test_agent_formation",
        runtime_credit_balance_usd_cents: 10
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        template_key: "start",
        name: "Metered Regent",
        slug: "metered",
        claimed_label: "metered",
        basename_fqdn: "metered.agent.base.eth",
        ens_fqdn: "metered.regent.eth",
        status: "published",
        public_summary: "Metering test company",
        sprite_name: "metered-sprite",
        sprite_service_name: "paperclip",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at: one_hour_ago,
        sprite_free_until: nil
      })
      |> Repo.insert!()

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    [sync_job] = all_enqueued(worker: SyncSpriteUsageRecordWorker)
    assert :ok == perform_job(worker_module(sync_job.worker), sync_job.args)

    updated_account = Repo.get!(BillingAccount, billing_account.id)
    updated_agent = Repo.get!(Agent, agent.id)
    usage_record = Repo.one!(SpriteUsageRecord)
    ledger_entry = Repo.one!(BillingLedgerEntry)

    assert updated_account.runtime_credit_balance_usd_cents == 0
    assert updated_agent.desired_runtime_state == "paused"
    assert updated_agent.observed_runtime_state == "paused"
    assert updated_agent.runtime_status == "paused"
    assert usage_record.usage_seconds >= 3600
    assert usage_record.status == "reported"
    assert usage_record.stripe_meter_event_id == "mtr_test_usage"
    assert ledger_entry.entry_type == "runtime_debit"
    assert ledger_entry.amount_usd_cents < 0
  end

  test "runtime usage sync worker retries a failed Stripe usage report" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-meter-retry",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: "cus_test_agent_formation",
        stripe_pricing_plan_subscription_id: "sub_test_agent_formation",
        runtime_credit_balance_usd_cents: 50
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        template_key: "start",
        name: "Metered Retry Regent",
        slug: "metered-retry",
        claimed_label: "metered-retry",
        basename_fqdn: "metered-retry.agent.base.eth",
        ens_fqdn: "metered-retry.regent.eth",
        status: "published",
        public_summary: "Metering retry company",
        sprite_name: "metered-retry-sprite",
        sprite_service_name: "paperclip",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at: one_hour_ago,
        sprite_free_until: nil
      })
      |> Repo.insert!()

    Application.put_env(
      :platform_phx,
      :stripe_fake_runtime_usage_result,
      {:error, "Stripe runtime reporting unavailable"}
    )

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    [sync_job] = all_enqueued(worker: SyncSpriteUsageRecordWorker)

    assert {:error, "Stripe runtime reporting unavailable"} ==
             perform_job(worker_module(sync_job.worker), sync_job.args)

    failed_record = Repo.one!(SpriteUsageRecord)
    assert failed_record.status == "failed"
    assert failed_record.stripe_sync_attempt_count == 1

    Application.put_env(:platform_phx, :stripe_fake_runtime_usage_result, :ok)

    assert :ok ==
             perform_job(SyncSpriteUsageRecordWorker, %{
               "sprite_usage_record_id" => failed_record.id
             })

    synced_record = Repo.get!(SpriteUsageRecord, failed_record.id)
    assert synced_record.status == "reported"
    assert synced_record.stripe_meter_event_id == "mtr_test_usage"
    assert synced_record.stripe_sync_attempt_count == 2
    assert is_struct(synced_record.stripe_reported_at, DateTime)
    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents < 50
    assert Repo.get!(Agent, agent.id).desired_runtime_state == "active"
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp worker_module(worker) when is_atom(worker), do: worker
  defp worker_module(worker) when is_binary(worker), do: Module.concat([worker])
end
