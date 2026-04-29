defmodule PlatformPhx.AgentPlatform.Billing do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.LlmUsageEvent
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.WelcomeCredits
  alias PlatformPhx.Repo

  @default_hermes_model "glm-5.1"

  def get_account(%HumanUser{} = human) do
    get_account_by_human_id(human.id)
  end

  def get_account(_human), do: nil

  def get_account_by_human_id(human_id) when is_integer(human_id) do
    Repo.one(from(account in BillingAccount, where: account.human_user_id == ^human_id))
  end

  def get_account_by_human_id(_human_id), do: nil

  def ensure_account(%HumanUser{} = human) do
    case get_account(human) do
      %BillingAccount{} = account ->
        {:ok, account}

      nil ->
        %BillingAccount{}
        |> BillingAccount.changeset(%{
          human_user_id: human.id,
          stripe_customer_id: human.stripe_customer_id,
          stripe_pricing_plan_subscription_id: human.stripe_pricing_plan_subscription_id,
          billing_status: human.stripe_llm_billing_status || "not_connected",
          runtime_credit_balance_usd_cents: 0
        })
        |> Repo.insert()
        |> case do
          {:ok, account} ->
            {:ok, account}

          {:error, %Ecto.Changeset{} = changeset} ->
            if Keyword.has_key?(changeset.errors, :human_user_id) do
              {:ok, get_account(human)}
            else
              {:error, changeset}
            end
        end
    end
  end

  def allows_runtime?(%BillingAccount{} = account) do
    (account.runtime_credit_balance_usd_cents || 0) > 0
  end

  def allows_runtime?(_account), do: false

  def account_payload(account, companies \\ [])

  def account_payload(nil, companies) do
    observability = runtime_cost_observability(nil, companies)

    paid_companies =
      Enum.count(List.wrap(companies), &(effective_metering_status(&1, nil) == "paid"))

    paused_companies =
      Enum.count(List.wrap(companies), &(effective_metering_status(&1, nil) == "paused"))

    trialing_companies =
      Enum.count(List.wrap(companies), &(effective_metering_status(&1, nil) == "trialing"))

    %{
      status: "not_connected",
      connected: false,
      provider: "stripe",
      customer_id: nil,
      subscription_id: nil,
      model_default: @default_hermes_model,
      margin_bps: 0,
      runtime_credit_balance_usd_cents: 0,
      free_day_ends_at: observability.free_day_ends_at,
      prepaid_drawdown_state: observability.prepaid_drawdown_state,
      last_usage_sync_at: observability.last_usage_sync_at,
      next_pause_threshold_usd_cents: observability.next_pause_threshold_usd_cents,
      pause_targets: observability.pause_targets,
      paid_companies: paid_companies,
      paused_companies: paused_companies,
      trialing_companies: trialing_companies,
      welcome_credit: nil
    }
  end

  def account_payload(%BillingAccount{} = account, companies) do
    observability = runtime_cost_observability(account, companies)

    resolved_status =
      case account.billing_status do
        "checkout_open" -> "checkout_open"
        "active" -> "active"
        "past_due" -> "past_due"
        "paused" -> "paused"
        _ -> "not_connected"
      end

    %{
      status: resolved_status,
      connected: resolved_status == "active",
      provider: "stripe",
      customer_id: account.stripe_customer_id,
      subscription_id: account.stripe_pricing_plan_subscription_id,
      model_default: @default_hermes_model,
      margin_bps: 0,
      runtime_credit_balance_usd_cents: account.runtime_credit_balance_usd_cents || 0,
      free_day_ends_at: observability.free_day_ends_at,
      prepaid_drawdown_state: observability.prepaid_drawdown_state,
      last_usage_sync_at: observability.last_usage_sync_at,
      next_pause_threshold_usd_cents: observability.next_pause_threshold_usd_cents,
      pause_targets: observability.pause_targets,
      paid_companies:
        Enum.count(List.wrap(companies), &(effective_metering_status(&1, account) == "paid")),
      paused_companies:
        Enum.count(List.wrap(companies), &(effective_metering_status(&1, account) == "paused")),
      trialing_companies:
        Enum.count(List.wrap(companies), &(effective_metering_status(&1, account) == "trialing")),
      welcome_credit: account |> WelcomeCredits.latest_grant() |> WelcomeCredits.payload()
    }
  end

  def usage_payload(%BillingAccount{} = account, companies) do
    runtime_spend_by_agent = runtime_spend_by_agent(account)
    llm_spend_by_agent = llm_spend_by_agent(account)
    observability = runtime_cost_observability(account, companies)

    company_summaries =
      Enum.map(companies, fn company ->
        %{
          slug: company.slug,
          name: company.name,
          runtime_status: effective_runtime_status(company),
          desired_runtime_state: company.desired_runtime_state,
          observed_runtime_state: company.observed_runtime_state,
          sprite_metering_status: effective_metering_status(company, account),
          sprite_free_until: iso(company.sprite_free_until),
          last_usage_sync_at: iso(agent_last_usage_sync_at(company)),
          will_pause_at_zero: runtime_pause_target?(company),
          runtime_spend_usd_cents: Map.get(runtime_spend_by_agent, company.id, 0),
          llm_spend_usd_cents: Map.get(llm_spend_by_agent, company.id, 0)
        }
      end)

    %{
      runtime_credit_balance_usd_cents: account.runtime_credit_balance_usd_cents || 0,
      free_day_ends_at: observability.free_day_ends_at,
      prepaid_drawdown_state: observability.prepaid_drawdown_state,
      last_usage_sync_at: observability.last_usage_sync_at,
      next_pause_threshold_usd_cents: observability.next_pause_threshold_usd_cents,
      pause_targets: observability.pause_targets,
      runtime_spend_usd_cents:
        Enum.reduce(company_summaries, 0, fn company, acc ->
          acc + company.runtime_spend_usd_cents
        end),
      llm_spend_usd_cents:
        Enum.reduce(company_summaries, 0, fn company, acc ->
          acc + company.llm_spend_usd_cents
        end),
      paid_companies: Enum.count(company_summaries, &(&1.sprite_metering_status == "paid")),
      paused_companies: Enum.count(company_summaries, &(&1.sprite_metering_status == "paused")),
      trialing_companies:
        Enum.count(company_summaries, &(&1.sprite_metering_status == "trialing")),
      welcome_credit: account |> WelcomeCredits.latest_grant() |> WelcomeCredits.payload(),
      companies: company_summaries
    }
  end

  def effective_runtime_status(%Agent{} = agent, billing_account \\ nil) do
    if agent.desired_runtime_state == "paused" or
         effective_metering_status(agent, billing_account) == "paused" do
      "paused"
    else
      agent.runtime_status
    end
  end

  def effective_metering_status(%Agent{} = agent, billing_account \\ nil) do
    cond do
      is_struct(agent.sprite_free_until, DateTime) and
          DateTime.compare(agent.sprite_free_until, PlatformPhx.Clock.utc_now()) == :gt ->
        "trialing"

      allows_runtime?(billing_account) ->
        "paid"

      true ->
        "paused"
    end
  end

  def runtime_cost_observability(billing_account, companies) do
    companies = List.wrap(companies)

    %{
      free_day_ends_at: iso(next_free_day_ends_at(companies)),
      prepaid_drawdown_state: prepaid_drawdown_state(billing_account, companies),
      last_usage_sync_at: iso(last_usage_sync_at(billing_account)),
      next_pause_threshold_usd_cents: 0,
      pause_targets: runtime_pause_targets(companies, billing_account)
    }
  end

  def agent_last_usage_sync_at(%Agent{id: agent_id}) when is_integer(agent_id) do
    Repo.one(
      from(record in SpriteUsageRecord,
        where: record.agent_id == ^agent_id and not is_nil(record.stripe_reported_at),
        select: max(record.stripe_reported_at)
      )
    )
  end

  def agent_last_usage_sync_at(_agent), do: nil

  def runtime_pause_target?(%Agent{} = agent) do
    agent.desired_runtime_state == "active" and agent.runtime_status != "paused_for_credits"
  end

  def runtime_pause_target?(_agent), do: false

  defp prepaid_drawdown_state(billing_account, companies) do
    cond do
      not is_nil(next_free_day_ends_at(companies)) ->
        "free_day"

      allows_runtime?(billing_account) ->
        "drawing_down"

      companies != [] ->
        "paused_at_zero"

      true ->
        "unavailable"
    end
  end

  defp runtime_pause_targets(companies, billing_account) do
    companies
    |> Enum.filter(&runtime_pause_target?/1)
    |> Enum.map(fn agent ->
      %{
        slug: agent.slug,
        name: agent.name,
        runtime_status: effective_runtime_status(agent, billing_account),
        desired_runtime_state: agent.desired_runtime_state,
        observed_runtime_state: agent.observed_runtime_state,
        free_day_ends_at: iso(agent.sprite_free_until)
      }
    end)
  end

  defp next_free_day_ends_at(companies) do
    now = PlatformPhx.Clock.utc_now()

    companies
    |> Enum.map(& &1.sprite_free_until)
    |> Enum.filter(&(is_struct(&1, DateTime) and DateTime.compare(&1, now) == :gt))
    |> Enum.sort(DateTime)
    |> List.first()
  end

  defp last_usage_sync_at(%BillingAccount{id: billing_account_id})
       when is_integer(billing_account_id) do
    Repo.one(
      from(record in SpriteUsageRecord,
        where:
          record.billing_account_id == ^billing_account_id and
            not is_nil(record.stripe_reported_at),
        select: max(record.stripe_reported_at)
      )
    )
  end

  defp last_usage_sync_at(_billing_account), do: nil

  defp runtime_spend_by_agent(%BillingAccount{id: nil}), do: %{}

  defp runtime_spend_by_agent(%BillingAccount{id: billing_account_id}) do
    Repo.all(
      from(record in SpriteUsageRecord,
        where: record.billing_account_id == ^billing_account_id,
        group_by: record.agent_id,
        select: {record.agent_id, coalesce(sum(record.amount_usd_cents), 0)}
      )
    )
    |> Map.new()
  end

  defp llm_spend_by_agent(%BillingAccount{human_user_id: nil}), do: %{}

  defp llm_spend_by_agent(%BillingAccount{human_user_id: human_user_id}) do
    Repo.all(
      from(event in LlmUsageEvent,
        where: event.human_user_id == ^human_user_id,
        group_by: event.agent_id,
        select: {event.agent_id, coalesce(sum(event.amount_usd_cents), 0)}
      )
    )
    |> Map.new()
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
end
