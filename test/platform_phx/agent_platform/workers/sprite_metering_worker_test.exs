defmodule PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorkerTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.Workers.SyncSpriteUsageRecordWorker
  alias PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorker
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)
    previous_sprites_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)

    previous_runtime_usage_result =
      Application.get_env(:platform_phx, :stripe_fake_runtime_usage_result)

    previous_secret = System.get_env("STRIPE_SECRET_KEY")
    previous_runtime_meter_name = System.get_env("STRIPE_RUNTIME_METER_EVENT_NAME")

    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_runtime_usage_result, :ok)

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")
    System.put_env("STRIPE_RUNTIME_METER_EVENT_NAME", "sprite_runtime_seconds")

    on_exit(fn ->
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)
      restore_app_env(:platform_phx, :runtime_registry_sprites_client, previous_sprites_client)

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
        billing_status: "not_connected",
        stripe_customer_id: unique_external_id("cus_metered"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_metered"),
        runtime_credit_balance_usd_cents: 10
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "metered").id,
        template_key: "start",
        name: "Metered Regent",
        slug: "metered",
        claimed_label: "metered",
        basename_fqdn: "metered.agent.base.eth",
        ens_fqdn: "metered.regent.eth",
        status: "published",
        public_summary: "Metering test company",
        sprite_name: "metered-sprite",
        sprite_service_name: "hermes-workspace",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at: one_hour_ago,
        sprite_free_until: nil
      })
      |> Repo.insert!()

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    usage_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

    assert :ok ==
             SyncSpriteUsageRecordWorker.perform(%Oban.Job{
               args: %{"sprite_usage_record_id" => usage_record.id},
               attempt: 1,
               max_attempts: 12
             })

    updated_account = Repo.get!(BillingAccount, billing_account.id)
    updated_agent = Repo.get!(Agent, agent.id)
    usage_record = Repo.get!(SpriteUsageRecord, usage_record.id)

    ledger_entry =
      Repo.one!(
        from(entry in BillingLedgerEntry,
          where: entry.source_ref == ^"sprite-usage:#{usage_record.id}"
        )
      )

    assert updated_account.runtime_credit_balance_usd_cents == 0
    assert updated_agent.desired_runtime_state == "active"
    assert updated_agent.observed_runtime_state == "paused"
    assert updated_agent.runtime_status == "paused_for_credits"
    assert usage_record.usage_seconds >= 3600
    assert usage_record.status == "reported"
    assert usage_record.stripe_meter_event_id == "mtr_test_usage"
    assert ledger_entry.entry_type == "runtime_debit"
    assert ledger_entry.amount_usd_cents < 0
  end

  test "trial runtime does not debit shared credit or enqueue Stripe usage" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-trial",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: unique_external_id("cus_trial"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_trial"),
        runtime_credit_balance_usd_cents: 75
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "trial-regent").id,
        template_key: "start",
        name: "Trial Regent",
        slug: "trial-regent",
        claimed_label: "trial-regent",
        basename_fqdn: "trial-regent.agent.base.eth",
        ens_fqdn: "trial-regent.regent.eth",
        status: "published",
        public_summary: "Trial company",
        sprite_name: "trial-regent-sprite",
        sprite_service_name: "hermes-workspace",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at: one_hour_ago,
        sprite_free_until:
          DateTime.add(DateTime.utc_now(), 3_600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert!()

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 75

    assert Repo.aggregate(
             from(record in SpriteUsageRecord, where: record.agent_id == ^agent.id),
             :count,
             :id
           ) == 0

    assert Repo.aggregate(
             from(entry in BillingLedgerEntry, where: entry.agent_id == ^agent.id),
             :count,
             :id
           ) == 0

    assert Repo.get!(Agent, agent.id).desired_runtime_state == "active"
  end

  test "an active paid account keeps the sprite running after the free period ends" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-paid-runtime",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: unique_external_id("cus_paid"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_paid"),
        runtime_credit_balance_usd_cents: 50
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "paid-runtime").id,
        template_key: "start",
        name: "Paid Runtime Regent",
        slug: "paid-runtime",
        claimed_label: "paid-runtime",
        basename_fqdn: "paid-runtime.agent.base.eth",
        ens_fqdn: "paid-runtime.regent.eth",
        status: "published",
        public_summary: "Paid company",
        sprite_name: "paid-runtime-sprite",
        sprite_service_name: "hermes-workspace",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at: one_hour_ago,
        sprite_free_until:
          DateTime.add(DateTime.utc_now(), -3_600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert!()

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    updated_agent = Repo.get!(Agent, agent.id)

    usage_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

    assert updated_agent.desired_runtime_state == "active"
    assert updated_agent.runtime_status == "ready"
    assert usage_record.status == "pending"
    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents < 50
  end

  test "an expired free day with no prepaid credit pauses the runtime without charging usage" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-expired-free-day",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: unique_external_id("cus_expired_free_day"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_expired_free_day"),
        runtime_credit_balance_usd_cents: 0
      })
      |> Repo.insert!()

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "expired-free-day").id,
        template_key: "start",
        name: "Expired Free Day Regent",
        slug: "expired-free-day",
        claimed_label: "expired-free-day",
        basename_fqdn: "expired-free-day.agent.base.eth",
        ens_fqdn: "expired-free-day.regent.eth",
        status: "published",
        public_summary: "Expired free day company",
        sprite_name: "expired-free-day-sprite",
        sprite_service_name: "hermes-workspace",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_last_checked_at:
          DateTime.utc_now() |> DateTime.add(-3_600, :second) |> DateTime.truncate(:second),
        sprite_free_until:
          DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert!()

    assert :ok = SpriteMeteringWorker.perform(%Oban.Job{args: %{}})

    updated_agent = Repo.get!(Agent, agent.id)

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 0
    assert updated_agent.desired_runtime_state == "active"
    assert updated_agent.observed_runtime_state == "paused"
    assert updated_agent.runtime_status == "paused_for_credits"

    assert Repo.aggregate(
             from(record in SpriteUsageRecord, where: record.agent_id == ^agent.id),
             :count,
             :id
           ) == 0
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
        stripe_customer_id: unique_external_id("cus_retry"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_retry"),
        runtime_credit_balance_usd_cents: 50
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "metered-retry").id,
        template_key: "start",
        name: "Metered Retry Regent",
        slug: "metered-retry",
        claimed_label: "metered-retry",
        basename_fqdn: "metered-retry.agent.base.eth",
        ens_fqdn: "metered-retry.regent.eth",
        status: "published",
        public_summary: "Metering retry company",
        sprite_name: "metered-retry-sprite",
        sprite_service_name: "hermes-workspace",
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

    usage_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

    assert {:error, "Stripe runtime reporting unavailable"} ==
             SyncSpriteUsageRecordWorker.perform(%Oban.Job{
               args: %{"sprite_usage_record_id" => usage_record.id},
               attempt: 1,
               max_attempts: 12
             })

    failed_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

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

  test "runtime usage failure restores local credit promptly and does not recover twice" do
    human =
      %HumanUser{}
      |> HumanUser.changeset(%{
        privy_user_id: "privy-meter-recover",
        wallet_address: @address,
        wallet_addresses: [@address]
      })
      |> Repo.insert!()

    billing_account =
      %BillingAccount{}
      |> BillingAccount.changeset(%{
        human_user_id: human.id,
        billing_status: "active",
        stripe_customer_id: unique_external_id("cus_recover"),
        stripe_pricing_plan_subscription_id: unique_external_id("sub_recover"),
        runtime_credit_balance_usd_cents: 1
      })
      |> Repo.insert!()

    one_hour_ago =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: create_company!(human, "recover-regent").id,
        template_key: "start",
        name: "Recover Regent",
        slug: "recover-regent",
        claimed_label: "recover-regent",
        basename_fqdn: "recover-regent.agent.base.eth",
        ens_fqdn: "recover-regent.regent.eth",
        status: "published",
        public_summary: "Recovery company",
        sprite_name: "recover-regent-sprite",
        sprite_service_name: "hermes-workspace",
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

    usage_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

    assert :ok ==
             SyncSpriteUsageRecordWorker.perform(%Oban.Job{
               args: %{"sprite_usage_record_id" => usage_record.id},
               attempt: 4,
               max_attempts: 12
             })

    recovered_account = Repo.get!(BillingAccount, billing_account.id)

    recovered_record =
      Repo.one!(
        from(record in SpriteUsageRecord,
          where: record.agent_id == ^agent.id,
          order_by: [desc: record.id],
          limit: 1
        )
      )

    recovery_entry =
      Repo.one!(
        from(entry in BillingLedgerEntry,
          where: entry.source_ref == ^"sprite-usage-recovery:#{recovered_record.id}"
        )
      )

    assert recovered_record.status == "failed"
    assert recovered_record.last_error_message =~ "restored"
    assert recovered_account.runtime_credit_balance_usd_cents > 0
    assert recovery_entry.entry_type == "manual_adjustment"
    assert Repo.get!(Agent, agent.id).desired_runtime_state == "active"

    Application.put_env(:platform_phx, :stripe_fake_runtime_usage_result, :ok)

    assert :ok ==
             SyncSpriteUsageRecordWorker.perform(%Oban.Job{
               args: %{"sprite_usage_record_id" => usage_record.id},
               attempt: 5,
               max_attempts: 12
             })

    assert Repo.aggregate(
             from(entry in BillingLedgerEntry,
               where: entry.source_ref == ^"sprite-usage-recovery:#{recovered_record.id}"
             ),
             :count,
             :id
           ) == 1

    assert Repo.get!(SpriteUsageRecord, recovered_record.id).status == "failed"
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp unique_external_id(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp create_company!(human, slug) do
    %Company{}
    |> Company.changeset(%{
      owner_human_id: human.id,
      name: "Runtime #{slug}",
      slug: slug,
      claimed_label: slug,
      status: "published",
      public_summary: "Runtime metering test company"
    })
    |> Repo.insert!()
  end
end
