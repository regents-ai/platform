defmodule PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker do
  @moduledoc false
  use Oban.Worker,
    queue: :billing,
    max_attempts: 10,
    unique: [period: {7, :days}, fields: [:worker, :args], keys: [:stripe_event_id]]

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Billing
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentPlatform.RuntimeTopups
  alias PlatformPhx.AgentPlatform.StripeEvent
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
  alias PlatformPhx.AgentPlatform.WelcomeCredits
  alias PlatformPhx.AgentPlatform.Workers.SyncTopupCreditGrantWorker
  alias PlatformPhx.Repo
  alias Oban

  @impl true
  def perform(%Oban.Job{args: %{"stripe_event_id" => stripe_event_id}}) do
    case Repo.get(StripeEvent, stripe_event_id) do
      %StripeEvent{} = event ->
        sync_stripe_event(event)

      nil ->
        {:cancel, "stripe event not found"}
    end
  end

  defp sync_stripe_event(%StripeEvent{processing_status: "processed"}), do: :ok

  defp sync_stripe_event(%StripeEvent{} = event) do
    args = StripeEvent.worker_args(event)

    result = dispatch_stripe_event(args)

    case result do
      :ok ->
        mark_processed!(event)
        :ok

      {:error, _reason} = error ->
        error

      {:cancel, _reason} = cancel ->
        cancel
    end
  end

  defp mark_processed!(%StripeEvent{} = event) do
    event
    |> StripeEvent.changeset(%{
      processing_status: "processed",
      processed_at: PlatformPhx.Clock.now()
    })
    |> Repo.update!()
  end

  defp dispatch_stripe_event(args) do
    case args["event_type"] do
      "checkout.session.completed" ->
        sync_checkout_completed(args)

      event_type
      when event_type in [
             "customer.subscription.updated",
             "customer.subscription.paused",
             "customer.subscription.resumed"
           ] ->
        sync_subscription_state(args)

      _other ->
        :ok
    end
  end

  defp sync_checkout_completed(args) do
    case metadata(args)["checkout_kind"] do
      "billing_setup" ->
        with {:ok, account} <- find_billing_account(args),
             {:ok, updated_account} <-
               update_billing_account(account, %{
                 stripe_customer_id: args["customer_id"] || account.stripe_customer_id,
                 stripe_pricing_plan_subscription_id:
                   args["subscription_id"] || account.stripe_pricing_plan_subscription_id,
                 billing_status: "active"
               }) do
          with :ok <- maybe_grant_welcome_credit(updated_account) do
            sync_runtime_state(updated_account, "active")
          end
        else
          {:cancel, _reason} = cancel -> cancel
          {:error, _reason} = error -> error
        end

      "runtime_topup" ->
        sync_runtime_topup(args)

      _other ->
        :ok
    end
  end

  defp sync_runtime_topup(args) do
    metadata = metadata(args)

    with {:ok, account} <- find_billing_account(args),
         amount when is_integer(amount) and amount > 0 <-
           normalize_positive_integer(metadata["amount_usd_cents"]) do
      source_ref = "stripe-event:#{args["event_id"]}"

      Repo.transaction(fn ->
        locked_account =
          Repo.one!(
            from row in BillingAccount,
              where: row.id == ^account.id,
              lock: "FOR UPDATE"
          )

        existing =
          Repo.one(
            from entry in BillingLedgerEntry,
              where: entry.source_ref == ^source_ref,
              limit: 1
          )

        if existing do
          case RuntimeTopups.maybe_enqueue_pending_sync(Repo.preload(existing, :billing_account)) do
            {:ok, _result} -> locked_account
            {:error, reason} -> Repo.rollback(reason)
          end
        else
          ledger_entry =
            %BillingLedgerEntry{}
            |> BillingLedgerEntry.changeset(%{
              billing_account_id: locked_account.id,
              entry_type: "topup",
              amount_usd_cents: amount,
              description: "Runtime credit added through Stripe Checkout.",
              source_ref: source_ref,
              effective_at: PlatformPhx.Clock.now(),
              stripe_sync_status: "pending",
              stripe_sync_attempt_count: 0
            })
            |> Repo.insert!()

          updated =
            locked_account
            |> BillingAccount.changeset(%{
              stripe_customer_id: args["customer_id"] || locked_account.stripe_customer_id,
              runtime_credit_balance_usd_cents:
                (locked_account.runtime_credit_balance_usd_cents || 0) + amount,
              billing_status:
                if(locked_account.billing_status == "not_connected",
                  do: "active",
                  else: locked_account.billing_status
                )
            })
            |> Repo.update!()

          from(agent in Agent, where: agent.owner_human_id == ^updated.human_user_id)
          |> Repo.update_all(
            set: [
              stripe_llm_billing_status: updated.billing_status,
              stripe_customer_id: updated.stripe_customer_id,
              stripe_pricing_plan_subscription_id: updated.stripe_pricing_plan_subscription_id
            ]
          )

          %{"billing_ledger_entry_id" => ledger_entry.id}
          |> SyncTopupCreditGrantWorker.new()
          |> Oban.insert!()

          updated
        end
      end)
      |> case do
        {:ok, updated_account} ->
          sync_runtime_state(updated_account, "active")

        {:error, _reason} = error ->
          error
      end
    else
      false -> {:cancel, "top-up amount missing"}
      {:cancel, _reason} = cancel -> cancel
      {:error, _reason} = error -> error
    end
  end

  defp sync_subscription_state(args) do
    with {:ok, account} <- find_billing_account(args) do
      status = normalize_status(args["event_type"], args["subscription_status"])

      with {:ok, updated_account} <-
             update_billing_account(account, %{
               stripe_customer_id: args["customer_id"] || account.stripe_customer_id,
               stripe_pricing_plan_subscription_id:
                 args["subscription_id"] || account.stripe_pricing_plan_subscription_id,
               billing_status: status
             }) do
        sync_runtime_state(updated_account, runtime_target_state(status))
      end
    else
      {:cancel, _reason} = cancel -> cancel
      {:error, _reason} = error -> error
    end
  end

  defp find_billing_account(args) do
    with query when not is_nil(query) <- billing_account_query(args),
         %BillingAccount{} = account <- Repo.one(query) do
      {:ok, account}
    else
      nil -> maybe_bootstrap_billing_account(args)
    end
  end

  defp billing_account_query(args) do
    metadata = metadata(args)
    billing_account_id = parse_integer(metadata["billing_account_id"])
    human_user_id = parse_integer(metadata["human_user_id"])

    cond do
      is_integer(billing_account_id) ->
        from(account in BillingAccount,
          where: account.id == ^billing_account_id
        )

      is_integer(human_user_id) ->
        from(account in BillingAccount,
          where: account.human_user_id == ^human_user_id
        )

      true ->
        nil
    end
  end

  defp maybe_bootstrap_billing_account(args) do
    case parse_integer(metadata(args)["human_user_id"]) do
      human_id when is_integer(human_id) ->
        case Repo.get(HumanUser, human_id) do
          %HumanUser{} = human -> Billing.ensure_account(human)
          nil -> {:cancel, "billing owner not found"}
        end

      nil ->
        {:cancel, "billing account not found"}
    end
  end

  defp update_billing_account(%BillingAccount{} = account, attrs) do
    Repo.transaction(fn ->
      locked_account =
        Repo.one!(
          from row in BillingAccount,
            where: row.id == ^account.id,
            lock: "FOR UPDATE"
        )

      updated =
        locked_account
        |> BillingAccount.changeset(attrs)
        |> Repo.update!()

      from(agent in Agent, where: agent.owner_human_id == ^updated.human_user_id)
      |> Repo.update_all(
        set: [
          stripe_llm_billing_status: updated.billing_status,
          stripe_customer_id: updated.stripe_customer_id,
          stripe_pricing_plan_subscription_id: updated.stripe_pricing_plan_subscription_id
        ]
      )

      updated
    end)
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_status("customer.subscription.paused", _subscription_status), do: "paused"
  defp normalize_status("customer.subscription.resumed", _subscription_status), do: "active"

  defp normalize_status(_event_type, subscription_status) do
    case subscription_status do
      "active" -> "active"
      "trialing" -> "active"
      "paused" -> "paused"
      "past_due" -> "past_due"
      "unpaid" -> "past_due"
      _ -> "not_connected"
    end
  end

  defp runtime_target_state("active"), do: "active"
  defp runtime_target_state("paused"), do: "paused"
  defp runtime_target_state("past_due"), do: "paused"
  defp runtime_target_state(_status), do: nil

  defp normalize_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> false
    end
  end

  defp normalize_positive_integer(_value), do: false

  defp metadata(args) when is_map(args), do: args["metadata"] || %{}

  defp parse_integer(value) when is_integer(value) and value > 0, do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp sync_runtime_state(_billing_account, nil), do: :ok

  defp sync_runtime_state(%BillingAccount{} = billing_account, target_state) do
    case RuntimeControl.sync_agents_for_billing_account(
           billing_account,
           target_state,
           source: "stripe_billing_sync"
         ) do
      {:ok, _result} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp maybe_grant_welcome_credit(%BillingAccount{} = account) do
    case WelcomeCredits.maybe_grant(account) do
      {:ok, {:granted, %WelcomeCreditGrant{} = grant, _updated_account}} ->
        sync_or_enqueue_welcome_credit(grant)

      {:ok, {:existing, %WelcomeCreditGrant{} = grant, _account}} ->
        maybe_enqueue_pending_sync(grant)
        :ok

      {:ok, {:limit_reached, nil, _account}} ->
        :ok

      {:ok, {:disabled, nil, _account}} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_or_enqueue_welcome_credit(%WelcomeCreditGrant{} = grant) do
    case WelcomeCredits.sync_stripe_credit_grant(grant) do
      {:ok, _result} ->
        :ok

      {:error, _message} ->
        maybe_enqueue_pending_sync(Repo.get!(WelcomeCreditGrant, grant.id))
        :ok
    end
  end

  defp maybe_enqueue_pending_sync(%WelcomeCreditGrant{stripe_sync_status: "synced"}), do: :ok

  defp maybe_enqueue_pending_sync(%WelcomeCreditGrant{} = grant) do
    case WelcomeCredits.enqueue_sync(grant) do
      {:ok, _job} -> :ok
      {:error, %Oban.Job{}} -> :ok
      {:error, _reason} -> :ok
    end
  end
end
