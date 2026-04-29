defmodule PlatformPhx.AgentPlatform.RuntimeTopups do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.StripeBilling
  alias PlatformPhx.AgentPlatform.Workers.SyncTopupCreditGrantWorker
  alias PlatformPhx.Repo
  alias Oban

  def sync_credit_grant(%BillingLedgerEntry{} = entry), do: do_sync_credit_grant(entry)

  def sync_credit_grant(entry_id) when is_integer(entry_id) do
    case Repo.get(BillingLedgerEntry, entry_id) do
      %BillingLedgerEntry{} = entry -> do_sync_credit_grant(entry)
      nil -> {:ok, :missing}
    end
  end

  def enqueue_sync(%BillingLedgerEntry{} = entry, opts \\ []) do
    %{"billing_ledger_entry_id" => entry.id}
    |> SyncTopupCreditGrantWorker.new(opts)
    |> oban_module().insert()
  end

  def maybe_enqueue_pending_sync(%BillingLedgerEntry{stripe_sync_status: "synced"}),
    do: {:ok, :already_synced}

  def maybe_enqueue_pending_sync(%BillingLedgerEntry{stripe_sync_status: "not_required"}),
    do: {:ok, :not_required}

  def maybe_enqueue_pending_sync(%BillingLedgerEntry{} = entry) do
    case enqueue_sync(entry) do
      {:ok, _job} -> {:ok, :enqueued}
      {:error, %Oban.Job{}} -> {:ok, :already_enqueued}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_sync_credit_grant(%BillingLedgerEntry{} = entry) do
    entry = Repo.preload(entry, :billing_account)

    cond do
      entry.entry_type != "topup" ->
        {:ok, :not_topup}

      entry.stripe_sync_status == "synced" ->
        {:ok, :already_synced}

      is_nil(entry.billing_account) ->
        {:ok, :missing_account}

      not is_binary(entry.source_ref) or entry.source_ref == "" ->
        {:ok, :missing_source_ref}

      true ->
        push_credit_grant(entry)
    end
  end

  defp push_credit_grant(%BillingLedgerEntry{} = entry) do
    next_attempt_count = entry.stripe_sync_attempt_count + 1
    now = PlatformPhx.Clock.now()

    case StripeBilling.create_credit_grant(
           entry.billing_account,
           entry.amount_usd_cents,
           entry.source_ref,
           idempotency_key: entry.source_ref
         ) do
      {:ok, result} ->
        updated =
          entry
          |> BillingLedgerEntry.changeset(%{
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
          entry
          |> BillingLedgerEntry.changeset(%{
            stripe_sync_status: "failed",
            stripe_sync_attempt_count: next_attempt_count,
            stripe_sync_last_error: message
          })
          |> Repo.update!()

        {:error, updated.stripe_sync_last_error}
    end
  end

  defp error_message({_, _, message}) when is_binary(message), do: message
  defp error_message({_, message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(reason), do: inspect(reason)

  defp oban_module do
    :platform_phx
    |> Application.get_env(:runtime_topups, [])
    |> Keyword.get(:oban_module, Oban)
  end
end
