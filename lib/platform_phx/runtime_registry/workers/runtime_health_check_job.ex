defmodule PlatformPhx.RuntimeRegistry.Workers.RuntimeHealthCheckJob do
  @moduledoc false

  use Oban.Worker,
    queue: :runtime_registry,
    max_attempts: 3,
    unique: [period: {5, :minutes}, keys: [:runtime_profile_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile

  @impl true
  def perform(%Job{args: %{"runtime_profile_id" => runtime_profile_id}}) do
    case RuntimeRegistry.get_runtime_profile(runtime_profile_id) do
      nil ->
        {:cancel, "runtime profile not found"}

      %RuntimeProfile{} = profile ->
        with {:ok, updated_profile} <- RuntimeRegistry.observe_sprites_capacity(profile),
             {:ok, services} <- RuntimeRegistry.sync_sprites_services(updated_profile),
             :ok <- observe_services(services) do
          :ok
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp observe_services(services) do
    Enum.reduce_while(services, :ok, fn service, :ok ->
      case RuntimeRegistry.observe_sprites_service(service) do
        {:ok, _service} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
