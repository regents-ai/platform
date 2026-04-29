defmodule PlatformPhx.AgentPlatform.RuntimeControl do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.SpriteAudit
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry.SpritesClient

  @type reason :: {:external, :sprite, String.t()} | {:not_found, String.t()}
  @type sync_failure :: %{agent_id: integer(), slug: String.t(), reason: term()}
  @type sync_result :: %{
          updated_agents: [Agent.t()],
          failed_agents: [sync_failure()],
          skipped_agents: [Agent.t()]
        }

  def pause(%Agent{} = agent, opts \\ []) do
    runtime_status = Keyword.get(opts, :runtime_status, "paused")
    preserve_desired_state? = Keyword.get(opts, :preserve_desired_state, false)

    with {:ok, current_agent} <- fetch_agent(agent.id),
         :ok <- audit_started(current_agent, "pause_runtime", opts),
         {:ok, _result} <- stop_sprite(current_agent),
         {:ok, updated} <-
           persist_agent_update(current_agent.id, fn locked_agent ->
             locked_agent
             |> Agent.changeset(%{
               desired_runtime_state:
                 desired_runtime_state_for_pause(locked_agent, preserve_desired_state?),
               observed_runtime_state: "paused",
               runtime_status: runtime_status,
               runtime_last_checked_at: now()
             })
             |> Repo.update()
           end),
         :ok <- audit_succeeded(updated, "pause_runtime", opts) do
      {:ok, updated}
      |> tap(fn _result -> AgentPlatform.clear_public_agent_cache(updated) end)
    else
      {:error, {:external, :sprite, _message} = reason} = error ->
        audit_failed(agent, "pause_runtime", opts, reason)
        mark_runtime_failure(agent.id, reason)
        error

      {:error, _reason} = error ->
        audit_failed(agent, "pause_runtime", opts, error)
        error
    end
  end

  def resume(%Agent{} = agent, opts \\ []) do
    with {:ok, current_agent} <- fetch_agent(agent.id),
         :ok <- audit_started(current_agent, "resume_runtime", opts),
         {:ok, _result} <- start_sprite(current_agent),
         {:ok, updated} <-
           persist_agent_update(current_agent.id, fn locked_agent ->
             locked_agent
             |> Agent.changeset(%{
               desired_runtime_state: "active",
               observed_runtime_state: "active",
               runtime_status: Keyword.get(opts, :runtime_status, "ready"),
               runtime_last_checked_at: now()
             })
             |> Repo.update()
           end),
         :ok <- audit_succeeded(updated, "resume_runtime", opts) do
      {:ok, updated}
      |> tap(fn _result -> AgentPlatform.clear_public_agent_cache(updated) end)
    else
      {:error, {:external, :sprite, _message} = reason} = error ->
        audit_failed(agent, "resume_runtime", opts, reason)
        mark_runtime_failure(agent.id, reason)
        error

      {:error, _reason} = error ->
        audit_failed(agent, "resume_runtime", opts, error)
        error
    end
  end

  def sync_agents_for_billing_account(
        %BillingAccount{} = billing_account,
        target_state,
        opts \\ []
      ) do
    result =
      Agent
      |> where([agent], agent.owner_human_id == ^billing_account.human_user_id)
      |> where([agent], agent.status == "published")
      |> order_by([agent], asc: agent.id)
      |> Repo.all()
      |> Enum.reduce(%{updated_agents: [], failed_agents: [], skipped_agents: []}, fn agent,
                                                                                      acc ->
        if runtime_sync_ready?(agent) and should_sync_agent?(agent, target_state) do
          case sync_agent(agent, target_state, opts) do
            {:ok, updated_agent} ->
              %{acc | updated_agents: [updated_agent | acc.updated_agents]}

            {:error, reason} ->
              failure = %{agent_id: agent.id, slug: agent.slug, reason: reason}
              %{acc | failed_agents: [failure | acc.failed_agents]}
          end
        else
          %{acc | skipped_agents: [agent | acc.skipped_agents]}
        end
      end)
      |> normalize_sync_result()

    case result.failed_agents do
      [] -> {:ok, result}
      [_ | _] -> {:error, {:runtime_sync_failed, result}}
    end
  end

  defp sync_agent(agent, "paused", opts) do
    pause(
      agent,
      preserve_desired_state: true,
      runtime_status: Keyword.get(opts, :runtime_status, "paused_for_credits")
    )
  end

  defp sync_agent(agent, "active", opts), do: resume(agent, opts)

  defp sync_agent(_agent, _target_state, _opts),
    do: {:error, {:not_found, "Unsupported runtime target state"}}

  defp should_sync_agent?(%Agent{desired_runtime_state: "paused"}, "active"), do: false
  defp should_sync_agent?(_agent, _target_state), do: true

  defp persist_agent_update(agent_id, callback) do
    Repo.transaction(fn ->
      case lock_agent(agent_id) do
        %Agent{} = agent ->
          case callback.(agent) do
            {:ok, updated} ->
              updated

            {:error, reason} ->
              Repo.rollback(reason)
          end

        nil ->
          Repo.rollback({:not_found, "Company not found"})
      end
    end)
    |> case do
      {:ok, %Agent{} = updated} ->
        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_agent(agent_id) do
    case Repo.get(Agent, agent_id) do
      %Agent{} = agent -> {:ok, agent}
      nil -> {:error, {:not_found, "Company not found"}}
    end
  end

  defp stop_sprite(agent) do
    case SpritesClient.stop_service(
           agent.sprite_name,
           agent.sprite_service_name || "hermes-workspace"
         ) do
      {:error, {:external, :sprites, message}} -> {:error, {:external, :sprite, message}}
      result -> result
    end
  end

  defp start_sprite(agent) do
    case SpritesClient.start_service(
           agent.sprite_name,
           agent.sprite_service_name || "hermes-workspace"
         ) do
      {:error, {:external, :sprites, message}} -> {:error, {:external, :sprite, message}}
      result -> result
    end
  end

  defp lock_agent(agent_id) do
    Repo.one(from agent in Agent, where: agent.id == ^agent_id, lock: "FOR UPDATE")
  end

  defp mark_runtime_failure(agent_id, {:external, :sprite, _message}) do
    case Repo.get(Agent, agent_id) do
      %Agent{} = agent ->
        result =
          agent
          |> Agent.changeset(%{runtime_status: "failed", runtime_last_checked_at: now()})
          |> Repo.update()

        AgentPlatform.clear_public_agent_cache(agent)
        result

      nil ->
        :ok
    end
  end

  defp mark_runtime_failure(_agent_id, _reason), do: :ok

  defp normalize_sync_result(result) do
    %{
      updated_agents: Enum.reverse(result.updated_agents),
      failed_agents: Enum.reverse(result.failed_agents),
      skipped_agents: Enum.reverse(result.skipped_agents)
    }
  end

  defp runtime_sync_ready?(%Agent{sprite_name: sprite_name}) when is_binary(sprite_name) do
    String.trim(sprite_name) != ""
  end

  defp runtime_sync_ready?(_agent), do: false

  defp desired_runtime_state_for_pause(agent, true), do: agent.desired_runtime_state
  defp desired_runtime_state_for_pause(_agent, false), do: "paused"

  defp now, do: PlatformPhx.Clock.now()

  defp audit_started(%Agent{} = agent, action, opts) do
    details = audit_details(agent)
    audit(actor_metadata(opts), agent, action, "started", nil, details)
  end

  defp audit_succeeded(%Agent{} = agent, action, opts) do
    details =
      audit_details(agent)
      |> Map.put(:runtime_status, agent.runtime_status)
      |> Map.put(:observed_runtime_state, agent.observed_runtime_state)
      |> Map.put(:desired_runtime_state, agent.desired_runtime_state)

    audit(actor_metadata(opts), agent, action, "succeeded", nil, details)
  end

  defp audit_failed(%Agent{} = agent, action, opts, reason) do
    audit(
      actor_metadata(opts),
      agent,
      action,
      "failed",
      format_reason(reason),
      audit_details(agent)
    )
  end

  defp audit(actor_metadata, %Agent{} = agent, action, status, message, details) do
    case SpriteAudit.log(agent, action, status, actor_metadata, message, details) do
      {:ok, _record} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  defp actor_metadata(opts) do
    %{
      actor_type: Keyword.get(opts, :actor_type, "system"),
      human_user_id: Keyword.get(opts, :human_user_id),
      source: Keyword.get(opts, :source, "runtime_control")
    }
  end

  defp audit_details(%Agent{} = agent) do
    %{
      sprite_name: agent.sprite_name,
      sprite_service_name: agent.sprite_service_name || "hermes-workspace",
      slug: agent.slug
    }
  end

  defp format_reason({:external, :sprite, message}) when is_binary(message), do: message
  defp format_reason({:not_found, message}) when is_binary(message), do: message
  defp format_reason({:error, reason}), do: format_reason(reason)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
