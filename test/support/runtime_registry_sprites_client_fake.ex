defmodule PlatformPhx.RuntimeRegistrySpritesClientFake do
  @moduledoc false

  @behaviour PlatformPhx.RuntimeRegistry.SpritesClient

  def list_services(runtime_id) do
    notify({:list_services, runtime_id})

    {:ok,
     [
       %{
         "id" => "svc-codex-workspace",
         "name" => "codex-workspace",
         "service_kind" => "workspace",
         "status" => "active",
         "endpoint_url" => "https://workspace.example.test"
       }
     ]}
  end

  def get_service(runtime_id, service_name) do
    notify({:get_service, runtime_id, service_name})
    {:ok, %{"name" => service_name, "status" => "active"}}
  end

  def create_service(runtime_id, attrs) do
    notify({:create_service, runtime_id, attrs})

    {:ok, Map.merge(%{"id" => "svc-#{attrs["name"]}", "status" => "active"}, Map.new(attrs))}
  end

  def start_service(runtime_id, service_name) do
    notify({:start_service, runtime_id, service_name})
    {:ok, %{"name" => service_name, "status" => "active"}}
  end

  def stop_service(runtime_id, service_name) do
    notify({:stop_service, runtime_id, service_name})
    {:ok, %{"name" => service_name, "status" => "paused"}}
  end

  def service_status(runtime_id, service_name) do
    notify({:service_status, runtime_id, service_name})
    {:ok, %{"name" => service_name, "status" => "active"}}
  end

  def service_logs(runtime_id, service_name, opts) do
    notify({:service_logs, runtime_id, service_name, opts})
    {:ok, %{"next_cursor" => "cursor-2", "excerpt" => "service ready"}}
  end

  def create_runtime(attrs) do
    notify({:create_runtime, attrs})

    {:ok,
     %{
       "id" => "sprite-runtime-#{attrs["runtime_profile_id"]}",
       "status" => "active",
       "memory_mb" => 2_048,
       "storage_bytes" => 1_024,
       "rate_limit_upgrade_url" => "https://sprites.example.test/upgrade?runtime=1#discard"
     }}
  end

  def get_runtime(runtime_id) do
    notify({:get_runtime, runtime_id})

    {:ok,
     %{
       "id" => runtime_id,
       "status" => "active",
       "memory_mb" => 4_096,
       "storage_bytes" => 2_048
     }}
  end

  def exec(runtime_id, attrs) do
    notify({:exec, runtime_id, attrs})
    {:ok, %{"exit_code" => 0, "stdout" => "ok", "stderr" => ""}}
  end

  def create_checkpoint(runtime_id, attrs) do
    notify({:create_checkpoint, runtime_id, attrs})

    {:ok,
     %{
       "id" => attrs["checkpoint_ref"],
       "checkpoint_ref" => attrs["checkpoint_ref"],
       "metadata" => %{"path" => "/workspace"}
     }}
  end

  def restore_checkpoint(runtime_id, checkpoint_ref) do
    notify({:restore_checkpoint, runtime_id, checkpoint_ref})
    {:ok, %{"checkpoint_ref" => checkpoint_ref, "restored" => true}}
  end

  def observe_capacity(runtime_id) do
    notify({:observe_capacity, runtime_id})

    {:ok,
     %{
       "memory_mb" => 16_384,
       "storage_bytes" => 8_192,
       "rateLimitUpgradeUrl" => "/billing/runtime"
     }}
  end

  defp notify(message) do
    case Application.get_env(:platform_phx, :runtime_registry_sprites_client_test_pid) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end
  end
end
