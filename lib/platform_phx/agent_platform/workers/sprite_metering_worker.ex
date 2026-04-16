defmodule PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorker do
  @moduledoc false
  use Oban.Worker, queue: :runtime_metering, max_attempts: 1

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentPlatform.SpriteRuntimeClient
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.Workers.SyncSpriteUsageRecordWorker
  alias PlatformPhx.Repo
  alias Oban

  @hourly_cost_usd_cents 25
  @runtime_meter_key "sprite_runtime_seconds"

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Agent
    |> where(
      [agent],
      agent.status in ["forming", "published"] and not is_nil(agent.owner_human_id)
    )
    |> Repo.all()
    |> Enum.each(&reconcile_agent(&1, now))

    :ok
  end

  defp reconcile_agent(%Agent{} = agent, now) do
    billing_account = load_billing_account(agent)

    with {:ok, service} <-
           SpriteRuntimeClient.service_state(
             agent.sprite_name,
             agent.sprite_service_name || "paperclip"
           ) do
      observed_state = service.state
      agent = persist_observed_state(agent, observed_state)

      cond do
        agent.desired_runtime_state == "paused" ->
          ensure_paused(agent)

        runtime_allowed?(agent, billing_account) ->
          reconcile_running_runtime(agent, billing_account, observed_state, now)

        true ->
          pause_for_balance(agent)
      end
    else
      {:error, _reason} -> :ok
    end
  end

  defp reconcile_running_runtime(agent, _billing_account, "paused", _now) do
    case RuntimeControl.resume(agent) do
      {:ok, _updated} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp reconcile_running_runtime(agent, %BillingAccount{} = billing_account, "active", now) do
    if trial_active?(agent, now) do
      agent
      |> Agent.changeset(%{runtime_last_checked_at: now, runtime_status: "ready"})
      |> Repo.update!()
    else
      bill_runtime_window(agent, billing_account, now)
    end
  end

  defp reconcile_running_runtime(agent, _billing_account, "active", now) do
    agent
    |> Agent.changeset(%{runtime_last_checked_at: now, runtime_status: "ready"})
    |> Repo.update!()
  end

  defp reconcile_running_runtime(agent, _billing_account, _observed_state, now) do
    agent
    |> Agent.changeset(%{runtime_last_checked_at: now, runtime_status: "ready"})
    |> Repo.update!()
  end

  defp bill_runtime_window(agent, billing_account, now) do
    window_started_at = agent.runtime_last_checked_at || now
    usage_seconds = max(DateTime.diff(now, window_started_at, :second), 0)

    if usage_seconds == 0 do
      agent
      |> Agent.changeset(%{runtime_last_checked_at: now})
      |> Repo.update!()
    else
      amount_usd_cents = runtime_charge_cents(usage_seconds)

      {:ok, {_usage_record, _updated_account, runtime_allowed_after_charge?}} =
        Repo.transaction(fn ->
          locked_account =
            Repo.one!(
              from account in BillingAccount,
                where: account.id == ^billing_account.id,
                lock: "FOR UPDATE"
            )

          locked_agent =
            Repo.one!(from row in Agent, where: row.id == ^agent.id, lock: "FOR UPDATE")

          usage_record =
            %SpriteUsageRecord{}
            |> SpriteUsageRecord.changeset(%{
              billing_account_id: locked_account.id,
              agent_id: locked_agent.id,
              meter_key: @runtime_meter_key,
              usage_seconds: usage_seconds,
              amount_usd_cents: amount_usd_cents,
              window_started_at: window_started_at,
              window_ended_at: now,
              status: "pending",
              stripe_sync_attempt_count: 0
            })
            |> Repo.insert!()

          %BillingLedgerEntry{}
          |> BillingLedgerEntry.changeset(%{
            billing_account_id: locked_account.id,
            agent_id: locked_agent.id,
            entry_type: "runtime_debit",
            amount_usd_cents: -amount_usd_cents,
            description: "Sprite runtime charge.",
            source_ref: "sprite-usage:#{usage_record.id}",
            effective_at: now
          })
          |> Repo.insert!()

          next_balance =
            max((locked_account.runtime_credit_balance_usd_cents || 0) - amount_usd_cents, 0)

          updated_account =
            locked_account
            |> BillingAccount.changeset(%{runtime_credit_balance_usd_cents: next_balance})
            |> Repo.update!()

          Repo.update!(
            Agent.changeset(locked_agent, %{
              runtime_last_checked_at: now,
              runtime_status:
                if(runtime_allowed?(locked_agent, updated_account),
                  do: "ready",
                  else: "paused_for_credits"
                )
            })
          )

          %{"sprite_usage_record_id" => usage_record.id}
          |> SyncSpriteUsageRecordWorker.new()
          |> Oban.insert!()

          {usage_record, updated_account, runtime_allowed?(locked_agent, updated_account)}
        end)

      if runtime_allowed_after_charge? do
        :ok
      else
        pause_for_balance(agent)
      end
    end
  end

  defp pause_for_balance(agent) do
    case RuntimeControl.pause(
           agent,
           preserve_desired_state: true,
           runtime_status: "paused_for_credits"
         ) do
      {:ok, _updated} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp ensure_paused(agent) do
    case RuntimeControl.pause(agent, runtime_status: "paused") do
      {:ok, _updated} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp persist_observed_state(agent, observed_state) do
    desired_observed =
      case observed_state do
        "active" -> "active"
        "paused" -> "paused"
        _ -> "unknown"
      end

    if agent.observed_runtime_state == desired_observed do
      agent
    else
      Repo.update!(Agent.changeset(agent, %{observed_runtime_state: desired_observed}))
    end
  end

  defp load_billing_account(%Agent{owner_human_id: nil}), do: nil

  defp load_billing_account(agent) do
    Repo.one(
      from account in BillingAccount, where: account.human_user_id == ^agent.owner_human_id
    )
  end

  defp runtime_allowed?(agent, billing_account) do
    trial_active?(agent, DateTime.utc_now() |> DateTime.truncate(:second)) or
      AgentPlatform.billing_allows_runtime?(billing_account)
  end

  defp trial_active?(agent, now) do
    is_struct(agent.sprite_free_until, DateTime) and
      DateTime.compare(agent.sprite_free_until, now) == :gt
  end

  defp runtime_charge_cents(seconds) when seconds > 0 do
    cents = div(seconds * @hourly_cost_usd_cents, 3600)
    if cents > 0, do: cents, else: 1
  end

  defp runtime_charge_cents(_seconds), do: 0
end
