defmodule PlatformPhx.AgentPlatform.Workers.RunFormationWorker do
  @moduledoc false
  @max_attempts 5
  use Oban.Worker,
    queue: :agent_formation,
    max_attempts: @max_attempts,
    unique: [period: :infinity, keys: [:agent_id], fields: [:args]]

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationProgress
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.SpriteAudit
  alias PlatformPhx.AgentPlatform.SpriteRunner
  alias PlatformPhx.AgentPlatform.SpriteRuntimeClient
  alias PlatformPhx.Repo

  @runner_steps [
    "create_sprite",
    "bootstrap_sprite",
    "bootstrap_workspace"
  ]

  @impl true
  def perform(%Oban.Job{args: %{"agent_id" => agent_id}} = job) do
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
         {:ok, agent, formation} <- verify_runtime(agent, formation),
         {:ok, _agent, _formation} <- publish_company(agent, formation) do
      :ok
    else
      nil ->
        {:cancel, "agent not found"}

      {:error, {:runtime_not_ready, state}} ->
        handle_runtime_not_ready(job, agent, formation, state)

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
    insert_event(formation, step, "started", "We're setting up your company now.")
    audit_started(agent, formation, step)
    SpriteRunner.run(agent, formation)
  end

  defp maybe_run_sprite(_agent, %FormationRun{} = formation) do
    {:ok, formation.metadata || %{}}
  end

  defp apply_runner_result(
         %Agent{} = agent,
         %FormationRun{current_step: step} = formation,
         result
       )
       when step in @runner_steps do
    Enum.each(@runner_steps, fn step ->
      insert_event(formation, step, "succeeded", success_message_for_step(step))
      audit_succeeded(agent, formation, step)
    end)

    formation =
      formation
      |> FormationRun.changeset(%{
        status: "running",
        current_step: "verify_runtime",
        sprite_command_log_path: result["log_path"] || formation.sprite_command_log_path,
        metadata: Map.merge(formation.metadata || %{}, result),
        last_heartbeat_at: now()
      })
      |> Repo.update!()

    agent =
      agent
      |> Agent.changeset(%{
        sprite_url: result["sprite_url"],
        workspace_url: result["workspace_url"],
        sprite_checkpoint_ref: result["checkpoint_ref"],
        sprite_created_at: now(),
        runtime_status: "forming",
        desired_runtime_state: "active",
        observed_runtime_state: "unknown",
        checkpoint_status: "ready",
        last_formation_error: nil
      })
      |> Repo.update!()

    {:ok, Repo.preload(agent, [:subdomain, :formation_run]), formation}
  end

  defp apply_runner_result(%Agent{} = agent, %FormationRun{} = formation, _result) do
    {:ok, Repo.preload(agent, [:subdomain, :formation_run]), formation}
  end

  defp verify_runtime(%Agent{} = agent, %FormationRun{} = formation) do
    insert_event(
      formation,
      "verify_runtime",
      "started",
      "We're checking that your company is responding."
    )

    with {:ok, runtime_state} <-
           SpriteRuntimeClient.service_state(
             agent.sprite_name,
             agent.sprite_service_name || "hermes-workspace"
           ),
         :ok <- require_active_runtime(runtime_state.state) do
      formation =
        formation
        |> FormationRun.changeset(%{
          current_step: "activate_subdomain",
          last_heartbeat_at: now()
        })
        |> Repo.update!()

      agent =
        agent
        |> Agent.changeset(%{
          runtime_status: "ready",
          observed_runtime_state: "active",
          runtime_last_checked_at: now(),
          last_formation_error: nil
        })
        |> Repo.update!()

      insert_event(
        formation,
        "verify_runtime",
        "succeeded",
        "Your company is responding and ready for launch."
      )

      {:ok, Repo.preload(agent, [:subdomain, :formation_run]), formation}
    else
      {:error, {:runtime_not_ready, state}} ->
        {:error, {:runtime_not_ready, state}}

      {:error, _reason} = error ->
        error
    end
  end

  defp publish_company(%Agent{} = agent, %FormationRun{} = formation) do
    insert_event(
      formation,
      "activate_subdomain",
      "started",
      "We're opening your public site."
    )

    insert_event(formation, "finalize", "started", "We're wrapping up your launch.")

    published_at = agent.published_at || now()
    completed_at = now()

    Repo.transaction(fn ->
      agent.subdomain
      |> Ecto.Changeset.change(active: true)
      |> Repo.update!()

      agent =
        agent
        |> Agent.changeset(%{
          status: "published",
          runtime_status: "ready",
          desired_runtime_state: "active",
          observed_runtime_state: "active",
          checkpoint_status: "ready",
          published_at: published_at,
          runtime_last_checked_at: completed_at
        })
        |> Repo.update!()

      formation =
        formation
        |> FormationRun.changeset(%{
          status: "succeeded",
          current_step: "finalize",
          completed_at: completed_at,
          last_heartbeat_at: completed_at
        })
        |> Repo.update!()

      activate_event =
        insert_event_without_broadcast(
          formation,
          "activate_subdomain",
          "succeeded",
          "Your public site is live."
        )

      finalize_event =
        insert_event_without_broadcast(
          formation,
          "finalize",
          "succeeded",
          "Your company is ready."
        )

      {Repo.preload(agent, [:subdomain, :formation_run]), formation,
       [activate_event, finalize_event]}
    end)
    |> case do
      {:ok, {published_agent, completed_formation, events}} ->
        Enum.each(events, &FormationProgress.broadcast(completed_formation, &1))
        {:ok, published_agent, completed_formation}

      {:error, reason} ->
        {:error, reason}
    end
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
    audit_failed(agent, formation, step, message)

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
    FormationProgress.insert_and_broadcast!(formation, step, status, message)
  end

  defp insert_event_without_broadcast(%FormationRun{} = formation, step, status, message) do
    FormationProgress.insert_event!(formation, step, status, message)
  end

  defp success_message_for_step("create_sprite"), do: "The first launch step is complete."
  defp success_message_for_step("bootstrap_sprite"), do: "Your company setup is in place."
  defp success_message_for_step("bootstrap_workspace"), do: "Your company workspace is ready."
  defp success_message_for_step(_step), do: "This launch step is complete."

  defp require_active_runtime("active"), do: :ok
  defp require_active_runtime(state), do: {:error, {:runtime_not_ready, state}}

  defp runtime_not_ready_message("paused"),
    do: "Your company setup finished, but the service is still paused."

  defp runtime_not_ready_message(_state),
    do: "Your company setup finished, but the service did not report ready yet."

  defp handle_runtime_not_ready(
         %Oban.Job{attempt: attempt, max_attempts: max_attempts},
         _agent,
         _formation,
         state
       )
       when attempt < max_attempts do
    {:error, {:external, :sprite, runtime_not_ready_message(state)}}
  end

  defp handle_runtime_not_ready(%Oban.Job{}, agent, formation, state) do
    fail(agent, formation, {:error, {:external, :sprite, runtime_not_ready_message(state)}})
  end

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp audit_started(%Agent{} = agent, %FormationRun{} = formation, action) do
    case SpriteAudit.log_formation(
           agent,
           formation,
           action,
           "started",
           audit_metadata(),
           nil,
           audit_details(agent)
         ) do
      {:ok, _record} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  defp audit_succeeded(%Agent{} = agent, %FormationRun{} = formation, action) do
    case SpriteAudit.log_formation(
           agent,
           formation,
           action,
           "succeeded",
           audit_metadata(),
           success_message_for_step(action),
           audit_details(agent)
         ) do
      {:ok, _record} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  defp audit_failed(%Agent{} = agent, %FormationRun{} = formation, action, message) do
    case SpriteAudit.log_formation(
           agent,
           formation,
           action,
           "failed",
           audit_metadata(),
           message,
           audit_details(agent)
         ) do
      {:ok, _record} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  defp audit_metadata do
    %{actor_type: "system", source: "run_formation_worker"}
  end

  defp audit_details(%Agent{} = agent) do
    %{
      slug: agent.slug,
      sprite_name: agent.sprite_name,
      sprite_service_name: agent.sprite_service_name || "hermes-workspace"
    }
  end
end
