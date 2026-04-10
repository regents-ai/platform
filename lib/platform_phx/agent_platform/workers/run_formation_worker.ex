defmodule PlatformPhx.AgentPlatform.Workers.RunFormationWorker do
  @moduledoc false
  use Oban.Worker,
    queue: :agent_formation,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:agent_id], fields: [:args]]

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationEvent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.SpriteRunner
  alias PlatformPhx.Repo

  @runner_steps [
    "create_sprite",
    "bootstrap_sprite",
    "bootstrap_paperclip",
    "create_company",
    "create_hermes",
    "create_checkpoint"
  ]

  @impl true
  def perform(%Oban.Job{args: %{"agent_id" => agent_id}}) do
    agent =
      Agent
      |> where([agent], agent.id == ^agent_id)
      |> preload([:formation_run, :subdomain, :owner_human])
      |> Repo.one()

    formation = agent && agent.formation_run

    with %Agent{} = agent <- agent,
         %FormationRun{} = formation <- formation,
         {:ok, formation} <- mark_running(formation),
         {:ok, result} <- maybe_run_sprite(agent, formation),
         {:ok, agent, formation} <- apply_runner_result(agent, formation, result),
         {:ok, agent, formation} <- activate_subdomain(agent, formation),
         {:ok, _agent, _formation} <- finalize(agent, formation) do
      :ok
    else
      nil ->
        {:discard, "agent not found"}

      {:error, _reason} = error ->
        fail(agent, formation, error)
    end
  end

  defp mark_running(%FormationRun{} = formation) do
    formation
    |> FormationRun.changeset(%{
      status: "running",
      current_step:
        if(formation.current_step == "reserve_claim",
          do: "create_sprite",
          else: formation.current_step
        ),
      attempt_count: (formation.attempt_count || 0) + 1,
      started_at: formation.started_at || now(),
      last_heartbeat_at: now(),
      last_error_step: nil,
      last_error_message: nil
    })
    |> Repo.update()
  end

  defp maybe_run_sprite(%Agent{} = agent, %FormationRun{current_step: step} = formation)
       when step in @runner_steps do
    insert_event(formation, step, "started", "Agent Formation is preparing the runtime.")
    SpriteRunner.run(agent, formation)
  end

  defp maybe_run_sprite(_agent, %FormationRun{} = formation) do
    {:ok, formation.metadata || %{}}
  end

  defp apply_runner_result(%Agent{} = agent, %FormationRun{} = formation, result) do
    Enum.each(@runner_steps, fn step ->
      insert_event(formation, step, "succeeded", "Completed #{String.replace(step, "_", " ")}.")
    end)

    formation =
      formation
      |> FormationRun.changeset(%{
        status: "running",
        current_step: "activate_subdomain",
        sprite_command_log_path: result["log_path"] || formation.sprite_command_log_path,
        metadata: Map.merge(formation.metadata || %{}, result),
        last_heartbeat_at: now()
      })
      |> Repo.update!()

    agent =
      agent
      |> Agent.changeset(%{
        sprite_url: result["sprite_url"],
        paperclip_url: result["paperclip_url"],
        paperclip_company_id: result["paperclip_company_id"],
        paperclip_agent_id: result["paperclip_agent_id"],
        sprite_checkpoint_ref: result["checkpoint_ref"],
        sprite_created_at: now(),
        runtime_status: "forming",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        checkpoint_status: "ready",
        runtime_last_checked_at: now(),
        last_formation_error: nil
      })
      |> Repo.update!()

    {:ok, Repo.preload(agent, [:subdomain, :formation_run]), formation}
  end

  defp activate_subdomain(%Agent{} = agent, %FormationRun{} = formation) do
    insert_event(
      formation,
      "activate_subdomain",
      "started",
      "Turning on the public company page."
    )

    agent.subdomain
    |> Ecto.Changeset.change(active: true)
    |> Repo.update!()

    formation =
      formation
      |> FormationRun.changeset(%{
        current_step: "finalize",
        last_heartbeat_at: now()
      })
      |> Repo.update!()

    insert_event(formation, "activate_subdomain", "succeeded", "The public subdomain is live.")

    {:ok, Repo.preload(agent, [:subdomain, :formation_run]), formation}
  end

  defp finalize(%Agent{} = agent, %FormationRun{} = formation) do
    insert_event(formation, "finalize", "started", "Finishing Agent Formation.")

    agent =
      agent
      |> Agent.changeset(%{
        status: "published",
        runtime_status: "ready",
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        checkpoint_status: "ready",
        published_at: agent.published_at || now(),
        runtime_last_checked_at: now()
      })
      |> Repo.update!()

    formation =
      formation
      |> FormationRun.changeset(%{
        status: "succeeded",
        current_step: "finalize",
        completed_at: now(),
        last_heartbeat_at: now()
      })
      |> Repo.update!()

    insert_event(formation, "finalize", "succeeded", "Agent Formation finished successfully.")
    {:ok, agent, formation}
  end

  defp fail(%Agent{} = agent, %FormationRun{} = formation, {:error, {_, _, message}}) do
    step = (formation && formation.current_step) || "create_sprite"
    persist_failure(agent, formation, step, message)
  end

  defp fail(%Agent{} = agent, %FormationRun{} = formation, {:error, {_, message}}) do
    step = (formation && formation.current_step) || "create_sprite"
    persist_failure(agent, formation, step, message)
  end

  defp fail(%Agent{} = agent, %FormationRun{} = formation, {:error, message})
       when is_binary(message) do
    step = (formation && formation.current_step) || "create_sprite"
    persist_failure(agent, formation, step, message)
  end

  defp fail(_agent, _formation, _reason), do: :ok

  defp persist_failure(%Agent{} = agent, %FormationRun{} = formation, step, message) do
    insert_event(formation, step, "failed", message)

    formation
    |> FormationRun.changeset(%{
      status: "failed",
      current_step: step,
      last_error_step: step,
      last_error_message: message,
      last_heartbeat_at: now()
    })
    |> Repo.update!()

    agent
    |> Agent.changeset(%{
      status: "failed",
      runtime_status: "failed",
      observed_runtime_state: "unknown",
      checkpoint_status: "failed",
      last_formation_error: message,
      runtime_last_checked_at: now()
    })
    |> Repo.update!()

    :ok
  end

  defp insert_event(%FormationRun{} = formation, step, status, message) do
    %FormationEvent{}
    |> FormationEvent.changeset(%{
      formation_id: formation.id,
      step: step,
      status: status,
      message: message
    })
    |> Repo.insert!()
  end

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end
end
