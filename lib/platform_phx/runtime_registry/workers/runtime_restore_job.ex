defmodule PlatformPhx.RuntimeRegistry.Workers.RuntimeRestoreJob do
  @moduledoc false

  use Oban.Worker,
    queue: :runtime_registry,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:runtime_checkpoint_id], fields: [:args]]

  alias Oban.Job
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint

  @impl true
  def perform(%Job{args: %{"runtime_checkpoint_id" => runtime_checkpoint_id}}) do
    case RuntimeRegistry.get_runtime_checkpoint(runtime_checkpoint_id) do
      nil ->
        {:cancel, "runtime checkpoint not found"}

      %RuntimeCheckpoint{} = checkpoint ->
        case RuntimeRegistry.restore_sprites_checkpoint(checkpoint) do
          {:ok, _checkpoint} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
