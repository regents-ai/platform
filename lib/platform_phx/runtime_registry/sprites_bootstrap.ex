defmodule PlatformPhx.RuntimeRegistry.SpritesBootstrap do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.SpritesClient
  alias PlatformPhx.RuntimeRegistry.SpritesPolicy
  alias PlatformPhx.RuntimeRegistry.SpritesService

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
         {:ok, _services} <- maybe_create_service(updated) do
      {:ok, updated}
    end
  end

  defp refresh_runtime(%RuntimeProfile{} = profile, runtime_id) do
    with {:ok, runtime} <- SpritesClient.get_runtime(runtime_id),
         {:ok, updated} <- persist_runtime(profile, Map.put(runtime, "id", runtime_id)),
         {:ok, _services} <- SpritesService.sync_services(updated) do
      {:ok, updated}
    end
  end

  defp maybe_create_service(%RuntimeProfile{} = profile) do
    service_name = profile.metadata["sprite_service_name"] || profile.config["service_name"]

    if is_binary(service_name) and service_name != "" do
      SpritesService.create_service(profile, %{
        "name" => service_name,
        "service_kind" => "workspace",
        "metadata" => %{"runtime_profile_id" => profile.id}
      })
      |> case do
        {:ok, service} -> {:ok, [service]}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, []}
    end
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
    %{
      "name" => profile.name,
      "runtime_profile_id" => profile.id,
      "company_id" => profile.company_id,
      "runner_kind" => profile.runner_kind,
      "metadata" => profile.metadata || %{}
    }
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
