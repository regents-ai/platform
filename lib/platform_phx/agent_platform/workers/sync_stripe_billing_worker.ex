defmodule PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker do
  @moduledoc false
  use Oban.Worker, queue: :billing, max_attempts: 10

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.RuntimeTopups
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
  alias PlatformPhx.AgentPlatform.WelcomeCredits
  alias PlatformPhx.AgentPlatform.Workers.SyncTopupCreditGrantWorker
  alias PlatformPhx.Repo
  alias Oban

  @impl true
  def perform(%Oban.Job{args: args}) do
    case args["event_type"] do
      "checkout.session.completed" ->
        sync_checkout_completed(args)

      "customer.subscription.updated" ->
        sync_subscription_state(args)

      "customer.subscription.paused" ->
        sync_subscription_state(args)

      "customer.subscription.resumed" ->
        sync_subscription_state(args)

      _other ->
        :ok
    end
  end

  defp sync_checkout_completed(args) do
    case args["metadata"]["checkout_kind"] do
      "billing_setup" ->
        with {:ok, account} <- find_billing_account(args) do
          updated_account =
            account
            |> BillingAccount.changeset(%{
              stripe_customer_id: args["customer_id"] || account.stripe_customer_id,
              stripe_pricing_plan_subscription_id:
                args["subscription_id"] || account.stripe_pricing_plan_subscription_id,
              billing_status: "active"
            })
            |> Repo.update!()

          maybe_grant_welcome_credit(updated_account)
        else
          {:error, _reason} = error -> error
        end

      "runtime_topup" ->
        sync_runtime_topup(args)

      _other ->
        :ok
    end
  end

  defp sync_runtime_topup(args) do
    with {:ok, account} <- find_billing_account(args),
         amount when is_integer(amount) and amount > 0 <-
           normalize_positive_integer(args["metadata"]["amount_usd_cents"]) do
      source_ref = "stripe-event:#{args["event_id"]}"

      Repo.transaction(fn ->
        existing =
          Repo.one(
            from entry in BillingLedgerEntry,
              where: entry.source_ref == ^source_ref,
              limit: 1
          )

        if existing do
          case RuntimeTopups.maybe_enqueue_pending_sync(Repo.preload(existing, :billing_account)) do
            {:ok, _result} -> account
            {:error, reason} -> Repo.rollback(reason)
          end
        else
          ledger_entry =
            %BillingLedgerEntry{}
            |> BillingLedgerEntry.changeset(%{
              billing_account_id: account.id,
              entry_type: "topup",
              amount_usd_cents: amount,
              description: "Runtime credit added through Stripe Checkout.",
              source_ref: source_ref,
              effective_at: DateTime.utc_now() |> DateTime.truncate(:second),
              stripe_sync_status: "pending",
              stripe_sync_attempt_count: 0
            })
            |> Repo.insert!()

          updated =
            account
            |> BillingAccount.changeset(%{
              runtime_credit_balance_usd_cents:
                (account.runtime_credit_balance_usd_cents || 0) + amount,
              billing_status:
                if(account.billing_status == "not_connected",
                  do: "active",
                  else: account.billing_status
                )
            })
            |> Repo.update!()

          from(agent in Agent, where: agent.owner_human_id == ^updated.human_user_id)
          |> Repo.update_all(
            set: [
              desired_runtime_state: "active",
              runtime_status: "ready"
            ]
          )

          %{"billing_ledger_entry_id" => ledger_entry.id}
          |> SyncTopupCreditGrantWorker.new()
          |> Oban.insert!()

          updated
        end
      end)
      |> case do
        {:ok, _updated_account} -> :ok
        {:error, _reason} = error -> error
      end
    else
      false -> {:discard, "top-up amount missing"}
      {:error, _reason} = error -> error
    end
  end

  defp sync_subscription_state(args) do
    with {:ok, account} <- find_billing_account(args) do
      status = normalize_status(args["event_type"], args["subscription_status"])

      Repo.transaction(fn ->
        updated =
          account
          |> BillingAccount.changeset(%{
            stripe_customer_id: args["customer_id"] || account.stripe_customer_id,
            stripe_pricing_plan_subscription_id:
              args["subscription_id"] || account.stripe_pricing_plan_subscription_id,
            billing_status: status
          })
          |> Repo.update!()

        agent_updates =
          case status do
            "paused" -> [desired_runtime_state: "paused", runtime_status: "paused"]
            "active" -> [desired_runtime_state: "active"]
            "past_due" -> [desired_runtime_state: "paused", runtime_status: "paused"]
            _ -> []
          end

        if agent_updates != [] do
          from(agent in Agent, where: agent.owner_human_id == ^updated.human_user_id)
          |> Repo.update_all(set: agent_updates)
        end
      end)

      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  defp find_billing_account(args) do
    metadata = args["metadata"] || %{}

    query =
      cond do
        is_binary(metadata["billing_account_id"]) and metadata["billing_account_id"] != "" ->
          from(account in BillingAccount,
            where: account.id == ^String.to_integer(metadata["billing_account_id"])
          )

        is_binary(metadata["human_user_id"]) and metadata["human_user_id"] != "" ->
          from(account in BillingAccount,
            where: account.human_user_id == ^String.to_integer(metadata["human_user_id"])
          )

        is_binary(args["customer_id"]) and args["customer_id"] != "" ->
          from(account in BillingAccount,
            where: account.stripe_customer_id == ^args["customer_id"]
          )

        true ->
          nil
      end

    case query && Repo.one(query) do
      %BillingAccount{} = account ->
        {:ok, account}

      nil ->
        maybe_bootstrap_billing_account(args)
    end
  end

  defp maybe_bootstrap_billing_account(args) do
    metadata = args["metadata"] || %{}

    case metadata["human_user_id"] do
      human_id when is_binary(human_id) and human_id != "" ->
        case Repo.get(HumanUser, String.to_integer(human_id)) do
          %HumanUser{} = human -> AgentPlatform.ensure_billing_account(human)
          nil -> {:discard, "billing owner not found"}
        end

      _ ->
        {:discard, "billing account not found"}
    end
  end

  defp normalize_status("customer.subscription.paused", _subscription_status), do: "paused"
  defp normalize_status("customer.subscription.resumed", _subscription_status), do: "active"
  defp normalize_status("checkout.session.completed", _subscription_status), do: "active"

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

  defp normalize_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> false
    end
  end

  defp normalize_positive_integer(_value), do: false

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
