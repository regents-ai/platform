defmodule PlatformPhx.RuntimeRegistry.Workers.RuntimeProvisionJob do
  @moduledoc false

  use Oban.Worker,
    queue: :runtime_registry,
    max_attempts: 5,
    unique: [period: {10, :minutes}, keys: [:runtime_profile_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile

  @impl true
  def perform(%Job{args: %{"runtime_profile_id" => runtime_profile_id}}) do
    case RuntimeRegistry.get_runtime_profile(runtime_profile_id) do
      nil ->
        {:cancel, "runtime profile not found"}

      %RuntimeProfile{} = profile ->
        case RuntimeRegistry.provision_sprites_runtime(profile) do
          {:ok, _profile} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
