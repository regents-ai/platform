defmodule PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorkerTest do
  use PlatformPhx.DataCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  import Ecto.Query

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.StripeEvent
  alias PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_sprites_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)
    previous_runtime_test_pid = Application.get_env(:platform_phx, :sprite_runtime_test_pid)

    previous_service_states =
      Application.get_env(:platform_phx, :sprite_runtime_service_states)

    previous_start_results = Application.get_env(:platform_phx, :sprite_runtime_start_results)
    previous_stop_results = Application.get_env(:platform_phx, :sprite_runtime_stop_results)

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    Application.put_env(:platform_phx, :sprite_runtime_test_pid, self())
    Application.put_env(:platform_phx, :sprite_runtime_service_states, %{})
    Application.put_env(:platform_phx, :sprite_runtime_start_results, %{})
    Application.put_env(:platform_phx, :sprite_runtime_stop_results, %{})

    on_exit(fn ->
      restore_app_env(:platform_phx, :runtime_registry_sprites_client, previous_sprites_client)
      restore_app_env(:platform_phx, :sprite_runtime_test_pid, previous_runtime_test_pid)
      restore_app_env(:platform_phx, :sprite_runtime_service_states, previous_service_states)
      restore_app_env(:platform_phx, :sprite_runtime_start_results, previous_start_results)
      restore_app_env(:platform_phx, :sprite_runtime_stop_results, previous_stop_results)
    end)

    :ok
  end

  test "top-up retries runtime reactivation failures without duplicating credit" do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    healthy_agent =
      insert_agent!(human, "healthy-runtime", %{
        desired_runtime_state: "active",
        observed_runtime_state: "paused",
        runtime_status: "paused_for_credits"
      })

    failing_agent =
      insert_agent!(human, "failing-runtime", %{
        desired_runtime_state: "active",
        observed_runtime_state: "paused",
        runtime_status: "paused_for_credits"
      })

    forming_agent =
      insert_agent!(human, "forming-runtime", %{
        status: "forming",
        desired_runtime_state: "active",
        observed_runtime_state: "paused",
        runtime_status: "forming"
      })

    Application.put_env(:platform_phx, :sprite_runtime_service_states, %{
      healthy_agent.sprite_name => "paused",
      failing_agent.sprite_name => "paused",
      forming_agent.sprite_name => "paused"
    })

    Application.put_env(:platform_phx, :sprite_runtime_start_results, %{
      failing_agent.sprite_name => {:error, {:external, :sprite, "start failed"}}
    })

    healthy_sprite_name = healthy_agent.sprite_name
    failing_sprite_name = failing_agent.sprite_name
    forming_sprite_name = forming_agent.sprite_name

    args = %{
      "event_id" => "evt_retry_topup",
      "event_type" => "checkout.session.completed",
      "customer_id" => billing_account.stripe_customer_id,
      "subscription_id" => nil,
      "subscription_status" => "complete",
      "mode" => "payment",
      "metadata" => %{
        "checkout_kind" => "runtime_topup",
        "human_user_id" => Integer.to_string(human.id),
        "billing_account_id" => Integer.to_string(billing_account.id),
        "amount_usd_cents" => "500"
      }
    }

    worker_args = worker_args_for_stripe_event(args)

    assert {:error, {:runtime_sync_failed, result}} =
             perform_job(SyncStripeBillingWorker, worker_args)

    assert Enum.map(result.updated_agents, & &1.slug) == [healthy_agent.slug]

    assert Enum.map(result.failed_agents, & &1.slug) == [failing_agent.slug]

    assert_receive {:start_service, ^healthy_sprite_name, "hermes-workspace"}
    assert_receive {:start_service, ^failing_sprite_name, "hermes-workspace"}
    refute_receive {:start_service, ^forming_sprite_name, "hermes-workspace"}

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 500

    assert Repo.aggregate(
             from(entry in BillingLedgerEntry,
               where: entry.source_ref == ^"stripe-event:evt_retry_topup"
             ),
             :count,
             :id
           ) == 1

    serialized_healthy_agent =
      Repo.get!(Agent, healthy_agent.id)
      |> Repo.preload([:subdomain, :services, :connections, :artifacts, formation_run: :events])
      |> AgentPlatform.serialize_agent(:private)

    assert serialized_healthy_agent.runtime_status == "ready"
    assert serialized_healthy_agent.sprite_metering_status == "paid"

    assert Repo.get!(Agent, healthy_agent.id).runtime_status == "ready"
    assert Repo.get!(Agent, failing_agent.id).runtime_status == "failed"
    assert Repo.get!(Agent, forming_agent.id).runtime_status == "forming"

    Application.put_env(:platform_phx, :sprite_runtime_start_results, %{})

    assert :ok = perform_job(SyncStripeBillingWorker, worker_args)

    assert_receive {:start_service, ^healthy_sprite_name, "hermes-workspace"}
    assert_receive {:start_service, ^failing_sprite_name, "hermes-workspace"}
    refute_receive {:start_service, ^forming_sprite_name, "hermes-workspace"}

    assert Repo.aggregate(
             from(entry in BillingLedgerEntry,
               where: entry.source_ref == ^"stripe-event:evt_retry_topup"
             ),
             :count,
             :id
           ) == 1

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 500
    assert Repo.get!(Agent, healthy_agent.id).runtime_status == "ready"
    assert Repo.get!(Agent, failing_agent.id).runtime_status == "ready"
  end

  test "top-up cancels when metadata ids are malformed" do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    args = %{
      "event_id" => "evt_malformed_topup",
      "event_type" => "checkout.session.completed",
      "customer_id" => billing_account.stripe_customer_id,
      "subscription_id" => nil,
      "subscription_status" => "complete",
      "mode" => "payment",
      "metadata" => %{
        "checkout_kind" => "runtime_topup",
        "human_user_id" => "not-a-number",
        "billing_account_id" => "still-not-a-number",
        "amount_usd_cents" => "125"
      }
    }

    assert {:cancel, "billing account not found"} =
             perform_job(SyncStripeBillingWorker, worker_args_for_stripe_event(args))

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 0

    assert Repo.aggregate(
             from(entry in BillingLedgerEntry,
               where: entry.source_ref == ^"stripe-event:evt_malformed_topup"
             ),
             :count,
             :id
           ) == 0
  end

  defp insert_human! do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-sync-billing",
      wallet_address: @address,
      wallet_addresses: [@address]
    })
    |> Repo.insert!()
  end

  defp insert_billing_account!(%HumanUser{} = human) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      billing_status: "not_connected",
      stripe_customer_id: unique_external_id("cus_sync_billing"),
      stripe_pricing_plan_subscription_id: unique_external_id("sub_sync_billing"),
      runtime_credit_balance_usd_cents: 0
    })
    |> Repo.insert!()
  end

  defp insert_agent!(%HumanUser{} = human, slug, overrides) do
    attrs =
      Map.merge(
        %{
          owner_human_id: human.id,
          template_key: "start",
          name: "#{slug} Regent",
          slug: slug,
          claimed_label: slug,
          basename_fqdn: "#{slug}.agent.base.eth",
          ens_fqdn: "#{slug}.regent.eth",
          status: "published",
          public_summary: "Billing sync company",
          sprite_name: "#{slug}-sprite",
          sprite_service_name: "hermes-workspace",
          runtime_status: "ready",
          desired_runtime_state: "active",
          observed_runtime_state: "active"
        },
        overrides
      )

    company =
      %Company{}
      |> Company.changeset(%{
        owner_human_id: human.id,
        name: attrs.name,
        slug: attrs.slug,
        claimed_label: attrs.claimed_label,
        status: attrs.status,
        public_summary: attrs.public_summary
      })
      |> Repo.insert!()

    %Agent{}
    |> Agent.changeset(Map.put(attrs, :company_id, company.id))
    |> Repo.insert!()
  end

  defp worker_args_for_stripe_event(event) do
    stripe_event =
      %StripeEvent{}
      |> StripeEvent.changeset(%{
        event_id: event["event_id"],
        event_type: event["event_type"],
        customer_id: event["customer_id"],
        subscription_id: event["subscription_id"],
        subscription_status: event["subscription_status"],
        mode: event["mode"],
        metadata: event["metadata"] || %{},
        processing_status: "queued"
      })
      |> Repo.insert!()

    %{"stripe_event_id" => stripe_event.id}
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp unique_external_id(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"
end
