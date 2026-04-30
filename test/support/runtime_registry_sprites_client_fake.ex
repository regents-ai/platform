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
       },
       %{
         "id" => "svc-regent-bridge",
         "name" => "regent-bridge",
         "service_kind" => "bridge",
         "status" => "active",
         "endpoint_url" => "https://bridge.example.test"
       }
     ]}
  end

  def get_service(runtime_id, service_name) do
    notify({:get_service, runtime_id, service_name})
    notify({:service_state, runtime_id, service_name})

    {:ok, %{"name" => service_name, "status" => service_state(runtime_id)}}
  end

  def create_service(runtime_id, attrs) do
    notify({:create_service, runtime_id, attrs})

    {:ok, Map.merge(%{"id" => "svc-#{attrs["name"]}", "status" => "active"}, Map.new(attrs))}
  end

  def start_service(runtime_id, service_name) do
    notify({:start_service, runtime_id, service_name})

    case runtime_result(:sprite_runtime_start_results, :sprite_runtime_start_result, runtime_id) do
      :ok -> {:ok, %{"name" => service_name, "status" => "active"}}
      {:error, _reason} = error -> error
    end
  end

  def stop_service(runtime_id, service_name) do
    notify({:stop_service, runtime_id, service_name})

    case runtime_result(:sprite_runtime_stop_results, :sprite_runtime_stop_result, runtime_id) do
      :ok -> {:ok, %{"name" => service_name, "status" => "paused"}}
      {:error, _reason} = error -> error
    end
  end

  def service_status(runtime_id, service_name) do
    notify({:service_status, runtime_id, service_name})
    notify({:service_state, runtime_id, service_name})

    {:ok, %{"name" => service_name, "status" => service_state(runtime_id)}}
  end

  def service_logs(runtime_id, service_name, opts) do
    notify({:service_logs, runtime_id, service_name, opts})
    {:ok, %{"next_cursor" => "#{service_name}-cursor-2", "excerpt" => "#{service_name} ready"}}
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

    command = Map.get(attrs, "command", "")

    cond do
      String.starts_with?(command, "cat ") and String.contains?(command, "REGENT_WORKFLOW.md") ->
        {:ok,
         %{
           "exit_code" => 0,
           "stdout" => """
           ---
           name: hosted-codex
           review_required: true
           ---
           Complete {{ work_item.title }}.
           """,
           "stderr" => ""
         }}

      String.contains?(command, "git status") ->
        {:ok, %{"exit_code" => 0, "stdout" => " M remote.txt\n?? proof.txt\n", "stderr" => ""}}

      String.contains?(command, "git diff") ->
        {:ok,
         %{
           "exit_code" => 0,
           "stdout" => "diff --git a/remote.txt b/remote.txt\n",
           "stderr" => ""
         }}

      String.contains?(command, "REGENT_TEST_OUTPUT.txt") ->
        {:ok, %{"exit_code" => 0, "stdout" => "mix test passed\n", "stderr" => ""}}

      String.contains?(command, "REGENT_PROMPT.md") ->
        {:ok,
         %{
           "exit_code" => 0,
           "stdout" => "Hosted Codex completed inside the Sprite.",
           "stderr" => ""
         }}

      true ->
        {:ok, %{"exit_code" => 0, "stdout" => "ok", "stderr" => ""}}
    end
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
    case Application.get_env(:platform_phx, :sprite_runtime_test_pid) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end

    case Application.get_env(:platform_phx, :runtime_registry_sprites_client_test_pid) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end
  end

  defp service_state(runtime_id) do
    case Application.get_env(:platform_phx, :sprite_runtime_transition_states, []) do
      [state | rest] ->
        Application.put_env(:platform_phx, :sprite_runtime_transition_states, rest)
        state

      [] ->
        Application.get_env(:platform_phx, :sprite_runtime_service_states, %{})
        |> Map.get(
          runtime_id,
          Application.get_env(:platform_phx, :sprite_runtime_service_state, "active")
        )
    end
  end

  defp runtime_result(map_key, scalar_key, runtime_id) do
    map_key
    |> then(&Application.get_env(:platform_phx, &1, %{}))
    |> Map.get(runtime_id, Application.get_env(:platform_phx, scalar_key, :ok))
  end
end
