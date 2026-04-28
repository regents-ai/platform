defmodule PlatformPhx.RuntimeRegistry.SpritesService do
  @moduledoc false

  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.RuntimeService
  alias PlatformPhx.RuntimeRegistry.SpritesClient

  def sync_services(%RuntimeProfile{} = profile) do
    with {:ok, runtime_id} <- RuntimeRegistry.provider_runtime_id(profile),
         {:ok, services} <- SpritesClient.list_services(runtime_id) do
      services
      |> Enum.map(&upsert_service(profile, &1))
      |> collect_results()
    end
  end

  def create_service(%RuntimeProfile{} = profile, attrs) do
    with {:ok, runtime_id} <- RuntimeRegistry.provider_runtime_id(profile),
         {:ok, service} <- SpritesClient.create_service(runtime_id, attrs) do
      upsert_service(profile, service)
    end
  end

  def start_service(%RuntimeService{} = service) do
    with {:ok, profile} <- fetch_profile(service),
         {:ok, runtime_id} <- RuntimeRegistry.provider_runtime_id(profile),
         {:ok, payload} <- SpritesClient.start_service(runtime_id, service.name) do
      persist_service_observation(service, payload)
    end
  end

  def stop_service(%RuntimeService{} = service) do
    with {:ok, profile} <- fetch_profile(service),
         {:ok, runtime_id} <- RuntimeRegistry.provider_runtime_id(profile),
         {:ok, payload} <- SpritesClient.stop_service(runtime_id, service.name) do
      persist_service_observation(service, payload)
    end
  end

  def observe_service(%RuntimeService{} = service) do
    with {:ok, profile} <- fetch_profile(service),
         {:ok, runtime_id} <- RuntimeRegistry.provider_runtime_id(profile),
         {:ok, status} <- SpritesClient.service_status(runtime_id, service.name),
         {:ok, logs} <-
           SpritesClient.service_logs(runtime_id, service.name, %{"cursor" => service.log_cursor}) do
      status
      |> Map.merge(%{"logs" => logs})
      |> then(&persist_service_observation(service, &1))
    end
  end

  defp upsert_service(%RuntimeProfile{} = profile, payload) do
    attrs = service_attrs(profile, payload)

    case Repo.get_by(RuntimeService, runtime_profile_id: profile.id, name: attrs.name) do
      %RuntimeService{} = service ->
        service
        |> RuntimeService.changeset(attrs)
        |> Repo.update()

      nil ->
        RuntimeRegistry.create_runtime_service(attrs)
    end
  end

  defp persist_service_observation(%RuntimeService{} = service, payload) do
    service
    |> RuntimeService.changeset(observation_attrs(payload))
    |> Repo.update()
  end

  defp service_attrs(%RuntimeProfile{} = profile, payload) do
    %{
      company_id: profile.company_id,
      runtime_profile_id: profile.id,
      name: payload["name"],
      service_kind: payload["service_kind"] || payload["kind"] || "workspace",
      status: normalize_status(payload),
      endpoint_url: payload["endpoint_url"] || payload["url"],
      provider_service_id: payload["id"],
      status_observed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      log_cursor: payload["log_cursor"],
      last_log_excerpt: payload["last_log_excerpt"],
      metadata: Map.get(payload, "metadata", %{})
    }
  end

  defp observation_attrs(payload) do
    logs = Map.get(payload, "logs", %{})

    %{
      status: normalize_status(payload),
      endpoint_url: payload["endpoint_url"] || payload["url"],
      status_observed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      log_cursor: logs["next_cursor"] || payload["log_cursor"],
      last_log_excerpt: logs["excerpt"] || payload["last_log_excerpt"],
      metadata: Map.get(payload, "metadata", %{})
    }
  end

  defp normalize_status(payload) do
    case payload["status"] || payload["state"] do
      status when status in ["active", "paused", "retired", "starting", "stopping", "failed"] ->
        status

      "running" ->
        "active"

      "started" ->
        "active"

      "stopped" ->
        "paused"

      _other ->
        "unknown"
    end
  end

  defp fetch_profile(%RuntimeService{runtime_profile_id: runtime_profile_id}) do
    case Repo.get(RuntimeProfile, runtime_profile_id) do
      %RuntimeProfile{} = profile -> {:ok, profile}
      nil -> {:error, :runtime_profile_not_found}
    end
  end

  defp collect_results(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, service}, {:ok, services} -> {:cont, {:ok, [service | services]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, services} -> {:ok, Enum.reverse(services)}
      error -> error
    end
  end
end
