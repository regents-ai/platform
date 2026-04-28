defmodule PlatformPhx.RuntimeRegistryTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeCheckpointJob
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeHealthCheckJob
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeProvisionJob
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeRestoreJob
  alias PlatformPhx.RuntimeRegistry.Workers.RuntimeUsageSnapshotJob

  setup do
    previous_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)
    previous_pid = Application.get_env(:platform_phx, :runtime_registry_sprites_client_test_pid)

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    Application.put_env(:platform_phx, :runtime_registry_sprites_client_test_pid, self())

    on_exit(fn ->
      restore_env(:runtime_registry_sprites_client, previous_client)
      restore_env(:runtime_registry_sprites_client_test_pid, previous_pid)
    end)

    :ok
  end

  test "registers and discovers a Sprite-backed hosted Codex runtime for a company agent" do
    %{company: company, agent: agent} = hosted_company_fixture("hosted-codex-register")

    assert {:ok, profile} =
             RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id, %{
               name: "Hosted Codex",
               runner_kind: "codex_exec"
             })

    assert profile.company_id == company.id
    assert profile.platform_agent_id == agent.id
    assert profile.execution_surface == "hosted_sprite"
    assert profile.runner_kind == "codex_exec"
    assert profile.billing_mode == "platform_hosted"
    assert profile.metadata["platform_agent_id"] == agent.id

    assert [discovered] = RuntimeRegistry.discover_hosted_codex_runtimes(company.id)
    assert discovered.id == profile.id
    assert discovered.platform_agent.id == agent.id
  end

  test "hosted runtime availability follows billing and runtime credit state" do
    %{company: company, agent: agent, billing_account: billing_account} =
      hosted_company_fixture("hosted-codex-billing",
        billing_status: "not_connected",
        runtime_credit_balance_usd_cents: 0
      )

    {:ok, profile} = RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id)

    assert %{available?: false, metering_status: "paused"} =
             RuntimeRegistry.hosted_runtime_availability(profile)

    billing_account
    |> BillingAccount.changeset(%{runtime_credit_balance_usd_cents: 25})
    |> Repo.update!()

    assert %{available?: true, metering_status: "paid"} =
             RuntimeRegistry.hosted_runtime_availability(profile)

    billing_account
    |> BillingAccount.changeset(%{
      billing_status: "active",
      runtime_credit_balance_usd_cents: 0
    })
    |> Repo.update!()

    assert %{available?: true, metering_status: "paid"} =
             RuntimeRegistry.hosted_runtime_availability(profile)
  end

  test "hosted usage records Sprite usage and billing linkage" do
    %{company: company, agent: agent, billing_account: billing_account} =
      hosted_company_fixture("hosted-codex-usage")

    {:ok, profile} = RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id)

    assert {:ok, %{snapshot: snapshot, sprite_usage_record: usage_record}} =
             RuntimeRegistry.record_hosted_sprite_usage(profile, %{
               active_seconds: 120,
               amount_usd_cents: 7,
               storage_bytes: 4096
             })

    assert snapshot.company_id == company.id
    assert snapshot.runtime_profile_id == profile.id
    assert snapshot.platform_sprite_usage_record_id == usage_record.id
    assert snapshot.provider == "sprites"
    assert snapshot.metadata["billing_mode"] == "platform_hosted"

    agent_id = agent.id
    assert %SpriteUsageRecord{agent_id: ^agent_id, amount_usd_cents: 7} = usage_record

    assert %BillingLedgerEntry{entry_type: "runtime_debit", amount_usd_cents: -7} =
             Repo.get_by!(BillingLedgerEntry, source_ref: "sprite-usage:#{usage_record.id}")

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 93
  end

  test "hosted usage rejects negative billing inputs without changing credit balance" do
    %{company: company, agent: agent, billing_account: billing_account} =
      hosted_company_fixture("hosted-codex-negative-usage")

    {:ok, profile} = RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id)

    assert {:error, changeset} =
             RuntimeRegistry.record_hosted_sprite_usage(profile, %{
               active_seconds: 60,
               amount_usd_cents: -5
             })

    assert %{amount_usd_cents: [_message]} = errors_on(changeset)
    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 100
    assert Repo.aggregate(SpriteUsageRecord, :count, :id) == 0
    assert Repo.aggregate(BillingLedgerEntry, :count, :id) == 0
  end

  test "local OpenClaw usage is self-reported and not charged as hosted compute" do
    %{company: company, billing_account: billing_account} =
      hosted_company_fixture("local-openclaw-usage")

    {:ok, profile} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "Local OpenClaw",
        runner_kind: "openclaw_local_executor",
        execution_surface: "local_bridge",
        billing_mode: "user_local"
      })

    assert {:ok, snapshot} =
             RuntimeRegistry.record_local_openclaw_usage(profile, %{active_seconds: 60})

    assert snapshot.provider == "openclaw_local"
    assert snapshot.platform_sprite_usage_record_id == nil
    assert snapshot.estimated_cost_usd == Decimal.new("0")
    assert snapshot.metadata["billing_mode"] == "user_local"
    assert Repo.aggregate(SpriteUsageRecord, :count, :id) == 0
    assert Repo.aggregate(BillingLedgerEntry, :count, :id) == 0
    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 100
  end

  test "runtime validation keeps OpenClaw local and Codex hosted" do
    %{company: company} = hosted_company_fixture("runtime-shape")

    assert {:error, hosted_openclaw} =
             RuntimeRegistry.create_runtime_profile(%{
               company_id: company.id,
               name: "Hosted OpenClaw",
               runner_kind: "openclaw_local_executor",
               execution_surface: "hosted_sprite",
               billing_mode: "platform_hosted"
             })

    assert %{execution_surface: [_], billing_mode: [_]} = errors_on(hosted_openclaw)

    assert {:error, local_codex} =
             RuntimeRegistry.create_runtime_profile(%{
               company_id: company.id,
               name: "Local Codex",
               runner_kind: "codex_exec",
               execution_surface: "local_bridge",
               billing_mode: "user_local"
             })

    assert %{execution_surface: [_], billing_mode: [_]} = errors_on(local_codex)
  end

  test "hosted Sprite protected checkpoint works and local OpenClaw protected checkpoint is rejected" do
    %{company: company, agent: agent} = hosted_company_fixture("hosted-codex-checkpoint")
    {:ok, hosted_profile} = RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id)

    assert {:ok, checkpoint} =
             RuntimeRegistry.create_hosted_sprite_checkpoint(hosted_profile, %{
               checkpoint_ref: "sprite-checkpoint-1"
             })

    assert checkpoint.protected == true
    assert checkpoint.status == "ready"

    {:ok, local_profile} =
      RuntimeRegistry.create_runtime_profile(%{
        company_id: company.id,
        name: "Local OpenClaw",
        runner_kind: "openclaw_local_executor",
        execution_surface: "local_bridge",
        billing_mode: "user_local"
      })

    assert {:error, {:bad_request, _message}} =
             RuntimeRegistry.create_hosted_sprite_checkpoint(local_profile, %{
               checkpoint_ref: "local-protected"
             })
  end

  test "provisions Sprite runtime, records capacity, and normalizes rate-limit upgrade URL" do
    %{company: company, agent: agent} = hosted_company_fixture("runtime-provision")
    {:ok, profile} = RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id)

    assert :ok =
             RuntimeProvisionJob.perform(%Oban.Job{
               args: %{"runtime_profile_id" => profile.id}
             })

    assert_receive {:create_runtime, %{"runtime_profile_id" => profile_id}}
    assert profile_id == profile.id
    assert_receive {:create_service, "sprite-runtime-" <> _, %{"name" => "codex-workspace"}}

    updated = RuntimeRegistry.get_runtime_profile(profile.id)
    assert updated.provider_runtime_id == "sprite-runtime-#{profile.id}"
    assert updated.observed_memory_mb == 2_048
    assert updated.observed_storage_bytes == 1_024
    assert updated.rate_limit_upgrade_url == "https://sprites.example.test/upgrade?runtime=1"

    assert [service] = RuntimeRegistry.list_runtime_services_for_profile(profile.id)
    assert service.name == "codex-workspace"
    assert service.status == "active"

    assert :ok =
             RuntimeProvisionJob.perform(%Oban.Job{
               args: %{"runtime_profile_id" => profile.id}
             })

    runtime_id = "sprite-runtime-#{profile.id}"
    assert_receive {:get_runtime, ^runtime_id}
    assert_receive {:list_services, ^runtime_id}
  end

  test "health check updates services, log cursor, and observed capacity" do
    %{company: company, agent: agent} = hosted_company_fixture("runtime-health")

    {:ok, profile} =
      RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id, %{
        provider_runtime_id: "sprite-health",
        observed_memory_mb: 2_048
      })

    assert :ok =
             RuntimeHealthCheckJob.perform(%Oban.Job{
               args: %{"runtime_profile_id" => profile.id}
             })

    assert_receive {:observe_capacity, "sprite-health"}
    assert_receive {:list_services, "sprite-health"}
    assert_receive {:service_status, "sprite-health", "codex-workspace"}
    assert_receive {:service_logs, "sprite-health", "codex-workspace", %{"cursor" => nil}}

    updated = RuntimeRegistry.get_runtime_profile(profile.id)
    assert updated.observed_memory_mb == 16_384
    assert updated.rate_limit_upgrade_url == "/billing/runtime"

    [service] = RuntimeRegistry.list_runtime_services_for_profile(profile.id)
    assert service.log_cursor == "cursor-2"
    assert service.last_log_excerpt == "service ready"
  end

  test "service controls and exec use Sprites client" do
    %{company: company, agent: agent} = hosted_company_fixture("runtime-service-exec")

    {:ok, profile} =
      RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id, %{
        provider_runtime_id: "sprite-service"
      })

    {:ok, service} =
      RuntimeRegistry.create_runtime_service(%{
        company_id: company.id,
        runtime_profile_id: profile.id,
        name: "codex-workspace",
        service_kind: "workspace",
        status: "active"
      })

    assert {:ok, %{"name" => "codex-workspace"}} =
             RuntimeRegistry.SpritesClient.get_service("sprite-service", "codex-workspace")

    assert_receive {:get_service, "sprite-service", "codex-workspace"}

    assert {:ok, paused} = RuntimeRegistry.stop_sprites_service(service)
    assert paused.status == "paused"
    assert_receive {:stop_service, "sprite-service", "codex-workspace"}

    assert {:ok, active} = RuntimeRegistry.start_sprites_service(paused)
    assert active.status == "active"
    assert_receive {:start_service, "sprite-service", "codex-workspace"}

    assert {:ok, %{"exit_code" => 0}} =
             RuntimeRegistry.exec_sprites_runtime(profile, %{"command" => "pwd"})

    assert_receive {:exec, "sprite-service", %{"command" => "pwd"}}
  end

  test "checkpoint and restore jobs keep filesystem rollback semantics" do
    %{company: company, agent: agent} = hosted_company_fixture("runtime-checkpoint-job")

    {:ok, profile} =
      RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id, %{
        provider_runtime_id: "sprite-checkpoint"
      })

    {:ok, checkpoint} =
      RuntimeRegistry.create_runtime_checkpoint(%{
        company_id: company.id,
        runtime_profile_id: profile.id,
        checkpoint_ref: "checkpoint-a",
        status: "pending"
      })

    assert :ok =
             RuntimeCheckpointJob.perform(%Oban.Job{
               args: %{"runtime_checkpoint_id" => checkpoint.id}
             })

    assert_receive {:create_checkpoint, "sprite-checkpoint",
                    %{"checkpoint_ref" => "checkpoint-a", "checkpoint_kind" => "filesystem"}}

    ready = RuntimeRegistry.get_runtime_checkpoint(checkpoint.id)
    assert ready.status == "ready"
    assert ready.protected == true
    assert ready.checkpoint_kind == "filesystem"
    assert ready.metadata["checkpoint_semantics"] == "filesystem_rollback_point"

    assert :ok =
             RuntimeRestoreJob.perform(%Oban.Job{
               args: %{"runtime_checkpoint_id" => ready.id}
             })

    assert_receive {:restore_checkpoint, "sprite-checkpoint", "checkpoint-a"}

    restored = RuntimeRegistry.get_runtime_checkpoint(ready.id)
    assert restored.restore_status == "succeeded"
    assert restored.metadata["checkpoint_semantics"] == "filesystem_rollback_point"
  end

  test "usage snapshot job records reported Sprites capacity" do
    %{company: company, agent: agent} = hosted_company_fixture("runtime-usage-job")

    {:ok, profile} =
      RuntimeRegistry.register_hosted_codex_runtime(company.id, agent.id, %{
        provider_runtime_id: "sprite-usage"
      })

    assert :ok =
             RuntimeUsageSnapshotJob.perform(%Oban.Job{
               args: %{"runtime_profile_id" => profile.id, "active_seconds" => 30}
             })

    assert_receive {:observe_capacity, "sprite-usage"}

    [snapshot] = RuntimeRegistry.list_usage_snapshots(company.id)
    assert snapshot.provider == "sprites"
    assert snapshot.reported_memory_mb == 16_384
    assert snapshot.reported_storage_bytes == 8_192
    assert snapshot.active_seconds == 30
  end

  defp hosted_company_fixture(slug, opts \\ []) do
    human = insert_human!(slug)
    company = insert_company!(human, slug)
    billing_account = insert_billing_account!(human, opts)
    agent = insert_agent!(human, company, slug)

    %{human: human, company: company, billing_account: billing_account, agent: agent}
  end

  defp insert_human!(key) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-runtime-registry-#{key}",
      wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      wallet_addresses: ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]
    })
    |> Repo.insert!()
  end

  defp insert_company!(human, slug) do
    {:ok, company} =
      AgentPlatform.create_company(human, %{
        name: "#{slug} Regent",
        slug: slug,
        claimed_label: slug,
        status: "published",
        public_summary: "#{slug} summary"
      })

    company
  end

  defp insert_billing_account!(human, opts) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      billing_status: Keyword.get(opts, :billing_status, "active"),
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      stripe_pricing_plan_subscription_id: "sub_#{System.unique_integer([:positive])}",
      runtime_credit_balance_usd_cents: Keyword.get(opts, :runtime_credit_balance_usd_cents, 100)
    })
    |> Repo.insert!()
  end

  defp insert_agent!(human, company, slug) do
    %Agent{}
    |> Agent.changeset(%{
      owner_human_id: human.id,
      company_id: company.id,
      template_key: "start",
      name: "#{slug} Hosted Agent",
      slug: "#{slug}-agent",
      claimed_label: "#{slug}-agent",
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "published",
      public_summary: "#{slug} hosted agent",
      sprite_name: "#{slug}-sprite",
      sprite_service_name: "codex-workspace",
      runtime_status: "ready",
      desired_runtime_state: "active",
      observed_runtime_state: "active",
      sprite_free_until: nil
    })
    |> Repo.insert!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:platform_phx, key)
  defp restore_env(key, value), do: Application.put_env(:platform_phx, key, value)
end
