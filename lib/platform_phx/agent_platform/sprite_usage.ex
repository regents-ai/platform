defmodule PlatformPhx.AgentPlatform.SpriteUsage do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.StripeBilling
  alias PlatformPhx.AgentPlatform.Workers.SyncSpriteUsageRecordWorker
  alias PlatformPhx.Repo
  alias Oban

  def sync_report(%SpriteUsageRecord{} = record), do: do_sync_report(record)

  def sync_report(record_id) when is_integer(record_id) do
    case Repo.get(SpriteUsageRecord, record_id) do
      %SpriteUsageRecord{} = record -> do_sync_report(record)
      nil -> {:ok, :missing}
    end
  end

  def enqueue_sync(%SpriteUsageRecord{} = record, opts \\ []) do
    %{"sprite_usage_record_id" => record.id}
    |> SyncSpriteUsageRecordWorker.new(opts)
    |> Oban.insert()
  end

  def recover_failed_report(record_id) when is_integer(record_id) do
    case Repo.get(SpriteUsageRecord, record_id) do
      %SpriteUsageRecord{} = record -> recover_failed_report(record)
      nil -> {:ok, :missing}
    end
  end

  def recover_failed_report(%SpriteUsageRecord{} = record) do
    record = Repo.preload(record, [:billing_account, :agent])

    Repo.transaction(fn ->
      locked_record =
        Repo.one!(
          from row in SpriteUsageRecord,
            where: row.id == ^record.id,
            lock: "FOR UPDATE"
        )
        |> Repo.preload([:billing_account, :agent])

      recovery_source_ref = recovery_source_ref(locked_record)

      existing_recovery =
        Repo.one(
          from entry in BillingLedgerEntry,
            where: entry.source_ref == ^recovery_source_ref,
            limit: 1
        )

      cond do
        locked_record.status == "reported" ->
          :already_reported

        is_nil(locked_record.billing_account) ->
          :missing_account

        existing_recovery ->
          :already_recovered

        true ->
          locked_account =
            Repo.one!(
              from account in BillingAccount,
                where: account.id == ^locked_record.billing_account_id,
                lock: "FOR UPDATE"
            )

          %BillingLedgerEntry{}
          |> BillingLedgerEntry.changeset(%{
            billing_account_id: locked_account.id,
            agent_id: locked_record.agent_id,
            entry_type: "manual_adjustment",
            amount_usd_cents: locked_record.amount_usd_cents,
            description: "Recovered runtime debit after Stripe usage reporting failed.",
            source_ref: recovery_source_ref,
            effective_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> Repo.insert!()

          updated_account =
            locked_account
            |> BillingAccount.changeset(%{
              runtime_credit_balance_usd_cents:
                (locked_account.runtime_credit_balance_usd_cents || 0) +
                  locked_record.amount_usd_cents
            })
            |> Repo.update!()

          updated_record =
            locked_record
            |> SpriteUsageRecord.changeset(%{
              last_error_message:
                combine_error_message(
                  locked_record.last_error_message,
                  "Local runtime credit was restored after Stripe usage reporting never succeeded."
                )
            })
            |> Repo.update!()

          {updated_record, updated_account}
      end
    end)
    |> case do
      {:ok, {updated_record, updated_account}} ->
        maybe_resume_agent(updated_record, updated_account)
        {:ok, :recovered}

      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_sync_report(%SpriteUsageRecord{} = record) do
    record = Repo.preload(record, :billing_account)

    cond do
      record.status == "reported" ->
        {:ok, :already_reported}

      recovered_report?(record) ->
        {:ok, :recovered}

      is_nil(record.billing_account) ->
        {:ok, :missing_account}

      true ->
        report_to_stripe(record)
    end
  end

  defp report_to_stripe(%SpriteUsageRecord{} = record) do
    next_attempt_count = record.stripe_sync_attempt_count + 1
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    sync_key = sync_key(record)

    case StripeBilling.report_runtime_usage(
           record,
           record.billing_account.stripe_customer_id,
           identifier: sync_key,
           idempotency_key: sync_key
         ) do
      {:ok, result} ->
        updated =
          record
          |> SpriteUsageRecord.changeset(%{
            status: "reported",
            stripe_meter_event_id: result.meter_event_id,
            stripe_sync_attempt_count: next_attempt_count,
            stripe_reported_at: now,
            last_error_message: nil
          })
          |> Repo.update!()

        {:ok, updated}

      {:error, reason} ->
        message = error_message(reason)

        updated =
          record
          |> SpriteUsageRecord.changeset(%{
            status: "failed",
            stripe_sync_attempt_count: next_attempt_count,
            last_error_message: message
          })
          |> Repo.update!()

        {:error, updated.last_error_message}
    end
  end

  defp sync_key(%SpriteUsageRecord{id: id}) when is_integer(id), do: "sprite-usage:#{id}"

  defp recovery_source_ref(%SpriteUsageRecord{id: id}) when is_integer(id),
    do: "sprite-usage-recovery:#{id}"

  defp recovered_report?(%SpriteUsageRecord{} = record) do
    Repo.one(
      from entry in BillingLedgerEntry,
        where: entry.source_ref == ^recovery_source_ref(record),
        select: entry.id,
        limit: 1
    ) != nil
  end

  defp error_message({_, _, message}) when is_binary(message), do: message
  defp error_message({_, message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(reason), do: inspect(reason)

  defp combine_error_message(nil, message), do: message
  defp combine_error_message("", message), do: message
  defp combine_error_message(existing, message), do: "#{existing} #{message}"

  defp maybe_resume_agent(
         %SpriteUsageRecord{agent: %Agent{} = agent},
         %BillingAccount{} = account
       ) do
    if agent.runtime_status == "paused_for_credits" and
         agent.desired_runtime_state == "active" and
         AgentPlatform.billing_allows_runtime?(account) do
      RuntimeControl.resume(agent, source: "sprite_usage_recovery")
      :ok
    else
      :ok
    end
  end

  defp maybe_resume_agent(_record, _account), do: :ok
end
