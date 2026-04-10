defmodule PlatformPhx.AgentPlatform.WelcomeCredits do
  @moduledoc false

  import Ecto.Query, warn: false

  require Logger

  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.PromotionCounter
  alias PlatformPhx.AgentPlatform.StripeBilling
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
  alias PlatformPhx.AgentPlatform.Workers.SyncWelcomeCreditGrantWorker
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig
  alias Oban

  @promotion_key "launch_welcome_credit"
  @credit_scope "runtime_only"

  def maybe_grant(%BillingAccount{} = account) do
    if RuntimeConfig.welcome_credit_enabled?() do
      grant_welcome_credit(account)
    else
      {:ok, {:disabled, nil, account}}
    end
  end

  def latest_grant(nil), do: nil
  def latest_grant(%BillingAccount{id: nil}), do: nil

  def latest_grant(%BillingAccount{} = account) do
    Repo.one(
      from grant in WelcomeCreditGrant,
        where: grant.billing_account_id == ^account.id,
        order_by: [desc: grant.granted_at, desc: grant.id],
        limit: 1
    )
  end

  def payload(nil), do: nil

  def payload(%WelcomeCreditGrant{} = grant) do
    %{
      status: effective_status(grant),
      amount_usd_cents: grant.amount_usd_cents,
      credit_scope: grant.credit_scope,
      granted_at: iso(grant.granted_at),
      expires_at: iso(grant.expires_at),
      stripe_sync_status: grant.stripe_sync_status,
      stripe_synced_at: iso(grant.stripe_synced_at)
    }
  end

  def sync_stripe_credit_grant(%WelcomeCreditGrant{} = grant),
    do: do_sync_stripe_credit_grant(grant)

  def sync_stripe_credit_grant(grant_id) when is_integer(grant_id) do
    case Repo.get(WelcomeCreditGrant, grant_id) do
      %WelcomeCreditGrant{} = grant -> do_sync_stripe_credit_grant(grant)
      nil -> {:ok, :missing}
    end
  end

  def enqueue_sync(%WelcomeCreditGrant{} = grant, opts \\ []) do
    %{"welcome_credit_grant_id" => grant.id}
    |> SyncWelcomeCreditGrantWorker.new(opts)
    |> Oban.insert()
  end

  def promotion_key, do: @promotion_key

  defp grant_welcome_credit(%BillingAccount{} = account) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    amount = RuntimeConfig.welcome_credit_amount_usd_cents()
    expiry_days = RuntimeConfig.welcome_credit_expiry_days()

    Repo.transaction(fn ->
      existing =
        Repo.one(
          from grant in WelcomeCreditGrant,
            where:
              grant.billing_account_id == ^account.id or
                grant.human_user_id == ^account.human_user_id,
            limit: 1
        )

      if existing do
        {:existing, existing, account}
      else
        ensure_counter!(now)

        counter =
          Repo.one!(
            from counter in PromotionCounter,
              where: counter.promotion_key == ^@promotion_key,
              lock: "FOR UPDATE"
          )

        existing_after_lock =
          Repo.one(
            from grant in WelcomeCreditGrant,
              where:
                grant.billing_account_id == ^account.id or
                  grant.human_user_id == ^account.human_user_id,
              limit: 1
          )

        cond do
          existing_after_lock ->
            {:existing, existing_after_lock, account}

          counter.next_rank > counter.limit_count ->
            {:limit_reached, nil, account}

          true ->
            granted_at = now
            expires_at = DateTime.add(granted_at, expiry_days * 86_400, :second)
            source_ref = "welcome-credit:#{account.id}"

            Repo.update!(PromotionCounter.changeset(counter, %{next_rank: counter.next_rank + 1}))

            grant =
              %WelcomeCreditGrant{}
              |> WelcomeCreditGrant.changeset(%{
                billing_account_id: account.id,
                human_user_id: account.human_user_id,
                grant_rank: counter.next_rank,
                amount_usd_cents: amount,
                credit_scope: @credit_scope,
                status: "active",
                granted_at: granted_at,
                expires_at: expires_at,
                stripe_sync_status: "pending",
                stripe_sync_attempt_count: 0,
                source_ref: source_ref
              })
              |> Repo.insert!()

            %BillingLedgerEntry{}
            |> BillingLedgerEntry.changeset(%{
              billing_account_id: account.id,
              entry_type: "welcome_credit",
              amount_usd_cents: amount,
              description: "Welcome credit for early signup.",
              source_ref: source_ref,
              effective_at: granted_at
            })
            |> Repo.insert!()

            updated_account =
              account
              |> BillingAccount.changeset(%{
                runtime_credit_balance_usd_cents:
                  (account.runtime_credit_balance_usd_cents || 0) + amount
              })
              |> Repo.update!()

            {:granted, grant, updated_account}
        end
      end
    end)
  end

  defp do_sync_stripe_credit_grant(%WelcomeCreditGrant{} = grant) do
    grant = Repo.preload(grant, :billing_account)

    cond do
      grant.status == "revoked" ->
        {:ok, :revoked}

      grant.stripe_sync_status == "synced" ->
        {:ok, :already_synced}

      not match?(%BillingAccount{}, grant.billing_account) ->
        {:ok, :missing_account}

      true ->
        account = grant.billing_account
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        next_attempt_count = grant.stripe_sync_attempt_count + 1

        case StripeBilling.create_credit_grant(account, grant.amount_usd_cents, grant.source_ref) do
          {:ok, result} ->
            updated =
              grant
              |> WelcomeCreditGrant.changeset(%{
                stripe_credit_grant_id: result.credit_grant_id,
                stripe_sync_status: "synced",
                stripe_sync_attempt_count: next_attempt_count,
                stripe_sync_last_error: nil,
                stripe_synced_at: now
              })
              |> Repo.update!()

            {:ok, updated}

          {:error, reason} ->
            message = error_message(reason)

            updated =
              grant
              |> WelcomeCreditGrant.changeset(%{
                stripe_sync_status: "failed",
                stripe_sync_attempt_count: next_attempt_count,
                stripe_sync_last_error: message
              })
              |> Repo.update!()

            if next_attempt_count >= 3 do
              Logger.warning(
                "Welcome credit Stripe sync failed for grant #{updated.id} after #{next_attempt_count} attempts: #{message}"
              )
            end

            {:error, message}
        end
    end
  end

  defp ensure_counter!(now) do
    %PromotionCounter{}
    |> PromotionCounter.changeset(%{
      promotion_key: @promotion_key,
      next_rank: 1,
      limit_count: RuntimeConfig.welcome_credit_limit()
    })
    |> Repo.insert(
      on_conflict: [
        set: [updated_at: now]
      ],
      conflict_target: :promotion_key
    )
  end

  defp effective_status(%WelcomeCreditGrant{
         status: "active",
         expires_at: %DateTime{} = expires_at
       }) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :lt, do: "expired", else: "active"
  end

  defp effective_status(%WelcomeCreditGrant{} = grant), do: grant.status

  defp error_message({_, _, message}) when is_binary(message), do: message
  defp error_message({_, message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(reason), do: inspect(reason)

  defp iso(nil), do: nil
  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
end
