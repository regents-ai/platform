defmodule PlatformPhx.AgentPlatform.SpriteUsage do
  @moduledoc false

  import Ecto.Query, warn: false

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

  defp do_sync_report(%SpriteUsageRecord{} = record) do
    record = Repo.preload(record, :billing_account)

    cond do
      record.status == "reported" ->
        {:ok, :already_reported}

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

  defp error_message({_, _, message}) when is_binary(message), do: message
  defp error_message({_, message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(reason), do: inspect(reason)
end
