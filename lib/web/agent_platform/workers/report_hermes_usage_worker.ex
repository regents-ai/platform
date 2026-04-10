defmodule Web.AgentPlatform.Workers.ReportHermesUsageWorker do
  @moduledoc false
  use Oban.Worker, queue: :billing, max_attempts: 20

  import Ecto.Query, warn: false

  alias Web.AgentPlatform.LlmUsageEvent
  alias Web.AgentPlatform.StripeLlmBilling
  alias Web.Repo

  @impl true
  def perform(%Oban.Job{args: %{"usage_event_id" => usage_event_id}}) do
    usage_event =
      LlmUsageEvent
      |> where([event], event.id == ^usage_event_id)
      |> preload([:human_user])
      |> Repo.one()

    case usage_event do
      %LlmUsageEvent{} = usage_event ->
        case StripeLlmBilling.report_usage(usage_event) do
          {:ok, result} ->
            usage_event
            |> LlmUsageEvent.changeset(%{
              status: "reported",
              stripe_meter_event_id: result.meter_event_id,
              last_error_message: nil
            })
            |> Repo.update!()

            :ok

          {:error, {_, _, message}} ->
            usage_event
            |> LlmUsageEvent.changeset(%{status: "failed", last_error_message: message})
            |> Repo.update!()

            {:error, message}

          {:error, {_, message}} ->
            usage_event
            |> LlmUsageEvent.changeset(%{status: "failed", last_error_message: message})
            |> Repo.update!()

            {:error, message}
        end

      nil ->
        {:discard, "usage event not found"}
    end
  end
end
