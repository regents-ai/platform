defmodule PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker do
  @moduledoc false
  use Oban.Worker, queue: :billing, max_attempts: 10

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.Repo

  @impl true
  def perform(%Oban.Job{args: args}) do
    customer_id = args["customer_id"]
    subscription_id = args["subscription_id"]
    human_user_id = args["metadata"]["human_user_id"]
    status = normalize_status(args["event_type"], args["subscription_status"])

    query =
      cond do
        is_binary(human_user_id) and human_user_id != "" ->
          from(human in HumanUser, where: human.id == ^String.to_integer(human_user_id))

        is_binary(customer_id) and customer_id != "" ->
          from(human in HumanUser, where: human.stripe_customer_id == ^customer_id)

        true ->
          nil
      end

    case query && Repo.one(query) do
      %HumanUser{} = human ->
        Repo.transaction(fn ->
          updated_human =
            human
            |> HumanUser.changeset(%{
              stripe_llm_billing_status: status,
              stripe_customer_id: customer_id || human.stripe_customer_id,
              stripe_pricing_plan_subscription_id:
                subscription_id || human.stripe_pricing_plan_subscription_id
            })
            |> Repo.update!()

          from(agent in Agent, where: agent.owner_human_id == ^updated_human.id)
          |> Repo.update_all(
            set: [
              stripe_llm_billing_status: status,
              stripe_customer_id: updated_human.stripe_customer_id,
              stripe_pricing_plan_subscription_id:
                updated_human.stripe_pricing_plan_subscription_id
            ]
          )
        end)

        :ok

      nil ->
        {:discard, "billing owner not found"}
    end
  end

  defp normalize_status("checkout.session.completed", _subscription_status), do: "active"

  defp normalize_status(_event_type, subscription_status) do
    case subscription_status do
      "active" -> "active"
      "trialing" -> "active"
      "past_due" -> "past_due"
      "unpaid" -> "past_due"
      _ -> "not_connected"
    end
  end
end
