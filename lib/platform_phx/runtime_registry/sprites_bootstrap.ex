defmodule PlatformPhx.RuntimeRegistry.SpritesBootstrap do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.RuntimeService
  alias PlatformPhx.RuntimeRegistry.SpritesClient
  alias PlatformPhx.RuntimeRegistry.SpritesPolicy
  alias PlatformPhx.RuntimeRegistry.SpritesService

  @default_workspace_service_name "codex-workspace"
  @default_bridge_service_name "regent-bridge"

  def provision_runtime(%RuntimeProfile{} = profile) do
    case profile.provider_runtime_id do
      runtime_id when is_binary(runtime_id) and runtime_id != "" ->
        refresh_runtime(profile, runtime_id)

      _missing ->
        create_runtime(profile)
    end
  end

  def observe_capacity(%RuntimeProfile{} = profile) do
    with {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, capacity} <- SpritesClient.observe_capacity(runtime_id) do
      persist_capacity(profile, capacity)
    end
  end

  defp create_runtime(%RuntimeProfile{} = profile) do
    with {:ok, runtime} <- SpritesClient.create_runtime(runtime_attrs(profile)),
         {:ok, updated} <- persist_runtime(profile, runtime),
         :ok <- run_bootstrap_script(updated),
         {:ok, services} <- ensure_bootstrap_services(updated),
         {:ok, _started_services} <- start_bootstrap_services(services),
         {:ok, _checkpoint} <- ensure_baseline_checkpoint(updated) do
      {:ok, updated}
    end
  end

  defp refresh_runtime(%RuntimeProfile{} = profile, runtime_id) do
    with {:ok, runtime} <- SpritesClient.get_runtime(runtime_id),
         {:ok, updated} <- persist_runtime(profile, Map.put(runtime, "id", runtime_id)),
         {:ok, _services} <- SpritesService.sync_services(updated),
         :ok <- run_bootstrap_script(updated),
         {:ok, services} <- ensure_bootstrap_services(updated),
         {:ok, _started_services} <- start_bootstrap_services(services),
         {:ok, _checkpoint} <- ensure_baseline_checkpoint(updated) do
      {:ok, updated}
    end
  end

  defp ensure_baseline_checkpoint(%RuntimeProfile{} = profile) do
    case Repo.get_by(RuntimeCheckpoint,
           runtime_profile_id: profile.id,
           checkpoint_ref: "baseline"
         ) do
      %RuntimeCheckpoint{} = checkpoint ->
        {:ok, checkpoint}

      nil ->
        create_baseline_checkpoint(profile)
    end
  end

  defp create_baseline_checkpoint(%RuntimeProfile{} = profile) do
    with {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, payload} <-
           SpritesClient.create_checkpoint(runtime_id, %{
             "checkpoint_ref" => "baseline",
             "checkpoint_kind" => "filesystem"
           }) do
      %RuntimeCheckpoint{}
      |> RuntimeCheckpoint.changeset(%{
        company_id: profile.company_id,
        runtime_profile_id: profile.id,
        checkpoint_ref: payload["checkpoint_ref"] || payload["id"] || "baseline",
        status: "ready",
        protected: true,
        checkpoint_kind: "filesystem",
        captured_at: PlatformPhx.Clock.now(),
        metadata:
          payload
          |> Map.get("metadata", %{})
          |> SpritesPolicy.checkpoint_metadata()
          |> Map.merge(%{"sprites_checkpoint" => payload, "checkpoint_reason" => "baseline"})
      })
      |> Repo.insert()
    end
  end

  defp ensure_bootstrap_services(%RuntimeProfile{} = profile) do
    profile
    |> bootstrap_service_attrs()
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, services} ->
      case Repo.get_by(RuntimeService, runtime_profile_id: profile.id, name: attrs["name"]) do
        %RuntimeService{} = service ->
          {:cont, {:ok, [service | services]}}

        nil ->
          case SpritesService.create_service(profile, attrs) do
            {:ok, service} -> {:cont, {:ok, [service | services]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
    |> case do
      {:ok, services} -> {:ok, Enum.reverse(services)}
      error -> error
    end
  end

  defp start_bootstrap_services(services) do
    Enum.reduce_while(services, {:ok, []}, fn service, {:ok, started} ->
      case SpritesService.start_service(service) do
        {:ok, updated_service} -> {:cont, {:ok, [updated_service | started]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, services} -> {:ok, Enum.reverse(services)}
      error -> error
    end
  end

  defp bootstrap_service_attrs(%RuntimeProfile{} = profile) do
    network_policy =
      profile
      |> network_policy()
      |> SpritesPolicy.network_policy()

    [
      %{
        "name" => workspace_service_name(profile),
        "service_kind" => "workspace",
        "network_policy" => network_policy,
        "metadata" => %{
          "runtime_profile_id" => profile.id,
          "bootstrap_role" => "workspace",
          "network_policy" => network_policy
        }
      },
      %{
        "name" => bridge_service_name(profile),
        "service_kind" => "bridge",
        "command" => "/regent/bin/regent-worker-bridge",
        "http_port" => 8765,
        "health_path" => "/healthz",
        "env" => bootstrap_env(profile),
        "network_policy" => network_policy,
        "metadata" => %{
          "runtime_profile_id" => profile.id,
          "bootstrap_role" => "regent_bridge",
          "command" => "/regent/bin/regent-worker-bridge",
          "health_path" => "/healthz",
          "network_policy" => network_policy
        }
      }
    ]
    |> Enum.reject(fn attrs -> attrs["name"] in [nil, ""] end)
  end

  defp persist_runtime(%RuntimeProfile{} = profile, runtime) do
    attrs =
      runtime
      |> SpritesPolicy.capacity_attrs()
      |> Map.merge(%{
        provider_runtime_id: runtime["id"] || runtime["runtime_id"],
        status: normalize_runtime_status(runtime),
        metadata: Map.merge(profile.metadata || %{}, %{"sprites_runtime" => runtime})
      })

    profile
    |> RuntimeProfile.changeset(attrs)
    |> Repo.update()
  end

  defp persist_capacity(%RuntimeProfile{} = profile, capacity) do
    attrs = SpritesPolicy.capacity_attrs(capacity)

    profile
    |> RuntimeProfile.changeset(attrs)
    |> Repo.update()
  end

  defp runtime_attrs(%RuntimeProfile{} = profile) do
    network_policy =
      profile
      |> network_policy()
      |> SpritesPolicy.network_policy()

    %{
      "name" => profile.name,
      "runtime_profile_id" => profile.id,
      "company_id" => profile.company_id,
      "runner_kind" => profile.runner_kind,
      "network_policy" => network_policy,
      "metadata" => profile.metadata || %{}
    }
  end

  defp run_bootstrap_script(%RuntimeProfile{} = profile) do
    with {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, payload} <-
           SpritesClient.exec(runtime_id, %{"command" => bootstrap_command(profile)}) do
      case payload do
        %{"exit_code" => 0} -> :ok
        %{"exit_code" => _status} -> {:error, {:sprite_bootstrap_failed, payload}}
        _payload -> {:error, {:sprite_bootstrap_failed, payload}}
      end
    end
  end

  defp bootstrap_command(%RuntimeProfile{} = profile) do
    script = Base.encode64(bootstrap_script())
    script_path = "/regent/bootstrap/regent_sprite_bootstrap.sh"
    env = bootstrap_env(profile)

    [
      "mkdir -p /regent/bootstrap",
      "printf %s #{shell_quote(script)} | base64 -d > #{shell_quote(script_path)}",
      "chmod +x #{shell_quote(script_path)}",
      "#{env_prefix(env)} #{shell_quote(script_path)}"
    ]
    |> Enum.join(" && ")
  end

  defp bootstrap_script do
    "runtime_bootstrap/regent_sprite_bootstrap.sh"
    |> priv_path()
    |> File.read!()
  end

  defp bootstrap_env(%RuntimeProfile{} = profile) do
    %{
      "REGENT_RUNTIME_ID" => profile.provider_runtime_id || "",
      "REGENT_COMPANY_ID" => to_string(profile.company_id),
      "REGENT_PLATFORM_BASE_URL" => platform_base_url()
    }
  end

  defp workspace_service_name(%RuntimeProfile{} = profile) do
    profile.metadata["sprite_service_name"] ||
      profile.config["service_name"] ||
      @default_workspace_service_name
  end

  defp bridge_service_name(%RuntimeProfile{} = profile) do
    profile.metadata["regent_bridge_service_name"] ||
      profile.config["bridge_service_name"] ||
      @default_bridge_service_name
  end

  defp network_policy(%RuntimeProfile{} = profile) do
    profile.metadata["network_policy"] ||
      profile.config["network_policy"] ||
      %{}
  end

  defp platform_base_url do
    :platform_phx
    |> Application.get_env(:rwr_platform_base_url, PlatformPhxWeb.Endpoint.url())
    |> String.trim_trailing("/")
  end

  defp env_prefix(env) do
    env
    |> Enum.map(fn {key, value} -> "#{key}=#{shell_quote(value)}" end)
    |> Enum.join(" ")
  end

  defp priv_path(relative_path) do
    case :code.priv_dir(:platform_phx) do
      path when is_list(path) -> Path.join([to_string(path), relative_path])
      {:error, _reason} -> Path.expand("../../../priv/#{relative_path}", __DIR__)
    end
  end

  defp shell_quote(value) do
    "'#{String.replace(to_string(value), "'", "'\"'\"'")}'"
  end

  defp provider_runtime_id(%RuntimeProfile{provider_runtime_id: runtime_id})
       when is_binary(runtime_id) and runtime_id != "",
       do: {:ok, runtime_id}

  defp provider_runtime_id(_profile), do: {:error, :runtime_not_provisioned}

  defp normalize_runtime_status(%{"status" => status})
       when status in ["active", "paused", "retired"],
       do: status

  defp normalize_runtime_status(%{"state" => "running"}), do: "active"
  defp normalize_runtime_status(%{"state" => "stopped"}), do: "paused"
  defp normalize_runtime_status(_runtime), do: "active"
end
