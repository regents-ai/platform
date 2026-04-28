defmodule PlatformPhx.RuntimeRegistry.Workers.RuntimeUsageSnapshotJob do
  @moduledoc false

  use Oban.Worker,
    queue: :runtime_registry,
    max_attempts: 3,
    unique: [period: {5, :minutes}, keys: [:runtime_profile_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile

  @impl true
  def perform(%Job{args: %{"runtime_profile_id" => runtime_profile_id} = args}) do
    case RuntimeRegistry.get_runtime_profile(runtime_profile_id) do
      nil ->
        {:cancel, "runtime profile not found"}

      %RuntimeProfile{} = profile ->
        case RuntimeRegistry.create_sprites_usage_snapshot(
               profile,
               Map.drop(args, ["runtime_profile_id"])
             ) do
          {:ok, _snapshot} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
