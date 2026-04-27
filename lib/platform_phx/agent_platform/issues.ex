defmodule PlatformPhx.AgentPlatform.Issues do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
  alias PlatformPhx.Repo

  @type issue :: %{
          surface: String.t(),
          title: String.t(),
          message: String.t(),
          action_path: String.t() | nil,
          source: String.t()
        }

  @spec for_human(HumanUser.t() | nil) :: [issue()]
  def for_human(nil), do: []

  def for_human(%HumanUser{id: human_id}) do
    account_ids = billing_account_ids(human_id)

    [
      failed_formations(human_id),
      failed_agent_runtime(human_id),
      failed_billing_entries(account_ids),
      failed_usage_records(account_ids),
      failed_welcome_credit_grants(human_id)
    ]
    |> List.flatten()
    |> Enum.uniq_by(&{&1.surface, &1.source})
    |> Enum.take(8)
  end

  @spec to_notice(issue()) :: %{tone: :error, message: String.t()}
  def to_notice(issue) do
    %{tone: :error, message: "#{issue.title}: #{issue.message}"}
  end

  defp billing_account_ids(human_id) do
    BillingAccount
    |> where([account], account.human_user_id == ^human_id)
    |> select([account], account.id)
    |> Repo.all()
  end

  defp failed_formations(human_id) do
    FormationRun
    |> where([formation], formation.human_user_id == ^human_id and formation.status == "failed")
    |> order_by([formation], desc: formation.updated_at)
    |> limit(3)
    |> Repo.all()
    |> Enum.map(fn formation ->
      %{
        surface: "formation",
        title: "Company opening needs attention",
        message:
          "The last company opening did not finish. Review the current step before trying again.",
        action_path: "/app/formation",
        source: "formation:#{formation.id}"
      }
    end)
  end

  defp failed_agent_runtime(human_id) do
    Agent
    |> where(
      [agent],
      agent.owner_human_id == ^human_id and
        (agent.runtime_status == "failed" or agent.checkpoint_status == "failed")
    )
    |> order_by([agent], desc: agent.updated_at)
    |> limit(3)
    |> Repo.all()
    |> Enum.map(fn agent ->
      %{
        surface: "runtime",
        title: "Company runtime needs attention",
        message: "#{agent.name} could not finish its latest status update.",
        action_path: "/app/dashboard",
        source: "agent:#{agent.id}"
      }
    end)
  end

  defp failed_billing_entries([]), do: []

  defp failed_billing_entries(account_ids) do
    BillingLedgerEntry
    |> where(
      [entry],
      entry.billing_account_id in ^account_ids and entry.stripe_sync_status == "failed"
    )
    |> order_by([entry], desc: entry.created_at)
    |> limit(3)
    |> Repo.all()
    |> Enum.map(fn entry ->
      %{
        surface: "billing",
        title: "Billing credit needs attention",
        message:
          "A payment credit could not be added yet. Check billing before relying on that balance.",
        action_path: "/app/billing",
        source: "billing_entry:#{entry.id}"
      }
    end)
  end

  defp failed_usage_records([]), do: []

  defp failed_usage_records(account_ids) do
    SpriteUsageRecord
    |> where(
      [record],
      record.billing_account_id in ^account_ids and record.status == "failed"
    )
    |> order_by([record], desc: record.window_ended_at)
    |> limit(3)
    |> Repo.all()
    |> Enum.map(fn record ->
      %{
        surface: "usage",
        title: "Usage update needs attention",
        message:
          "A company usage update could not be recorded yet. Review billing before making changes.",
        action_path: "/app/billing",
        source: "usage_record:#{record.id}"
      }
    end)
  end

  defp failed_welcome_credit_grants(human_id) do
    WelcomeCreditGrant
    |> where(
      [grant],
      grant.human_user_id == ^human_id and grant.stripe_sync_status == "failed"
    )
    |> order_by([grant], desc: grant.updated_at)
    |> limit(3)
    |> Repo.all()
    |> Enum.map(fn grant ->
      %{
        surface: "welcome_credit",
        title: "Launch credit needs attention",
        message:
          "A launch credit could not be added yet. Check billing before opening another company.",
        action_path: "/app/billing",
        source: "welcome_credit:#{grant.id}"
      }
    end)
  end
end
