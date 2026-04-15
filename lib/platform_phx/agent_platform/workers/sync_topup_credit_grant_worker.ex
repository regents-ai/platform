defmodule PlatformPhx.AgentPlatform.Workers.SyncTopupCreditGrantWorker do
  @moduledoc false
  use Oban.Worker,
    queue: :billing,
    max_attempts: 12,
    unique: [period: 60, fields: [:worker, :args]]

  alias PlatformPhx.AgentPlatform.RuntimeTopups
  alias Oban.Job

  @retry_schedule [60, 300, 1_800, 7_200, 43_200, 86_400, 86_400, 86_400, 86_400, 86_400, 86_400]

  @impl true
  def perform(%Job{args: %{"billing_ledger_entry_id" => entry_id}}) do
    case RuntimeTopups.sync_credit_grant(entry_id) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def backoff(%Job{attempt: attempt}) do
    index = min(max(attempt - 1, 0), length(@retry_schedule) - 1)
    Enum.at(@retry_schedule, index)
  end
end
