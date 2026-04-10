defmodule PlatformPhx.AgentPlatform.Workers.SpriteMeteringWorker do
  @moduledoc false
  use Oban.Worker, queue: :runtime_metering, max_attempts: 1

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.CreditLedger
  alias PlatformPhx.Repo

  @hourly_cost_usd_cents 25

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Agent
    |> where([agent], agent.status in ["forming", "published"])
    |> Repo.all()
    |> Enum.each(&meter_agent(&1, now))

    :ok
  end

  defp meter_agent(%Agent{} = agent, now) do
    cond do
      is_struct(agent.sprite_free_until, DateTime) and
          DateTime.compare(agent.sprite_free_until, now) == :gt ->
        :ok

      (agent.sprite_credit_balance_usd_cents || 0) > 0 ->
        Repo.transaction(fn ->
          %CreditLedger{}
          |> CreditLedger.changeset(%{
            agent_id: agent.id,
            entry_type: "runtime_debit",
            amount_usd_cents: -@hourly_cost_usd_cents,
            description: "Hourly Sprite runtime charge.",
            source_ref: "sprite-metering",
            effective_at: now
          })
          |> Repo.insert!()

          next_balance =
            max((agent.sprite_credit_balance_usd_cents || 0) - @hourly_cost_usd_cents, 0)

          agent
          |> Agent.changeset(%{
            sprite_credit_balance_usd_cents: next_balance,
            sprite_metering_status: if(next_balance > 0, do: "paid", else: "paused"),
            runtime_status: if(next_balance > 0, do: "ready", else: "paused_for_credits"),
            runtime_last_checked_at: now
          })
          |> Repo.update!()
        end)

      true ->
        agent
        |> Agent.changeset(%{
          sprite_metering_status: "paused",
          runtime_status: "paused_for_credits",
          runtime_last_checked_at: now
        })
        |> Repo.update!()
    end
  end
end
