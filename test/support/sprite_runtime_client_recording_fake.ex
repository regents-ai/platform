defmodule PlatformPhx.SpriteRuntimeClientRecordingFake do
  @moduledoc false

  def service_state(sprite_name, service_name) do
    maybe_notify({:service_state, sprite_name, service_name})

    {:ok,
     %{
       state: Application.get_env(:platform_phx, :sprite_runtime_service_state, "active")
     }}
  end

  def stop_service(sprite_name, service_name) do
    maybe_notify({:stop_service, sprite_name, service_name})

    case Application.get_env(:platform_phx, :sprite_runtime_stop_result, :ok) do
      :ok -> {:ok, %{state: "paused"}}
      {:error, _reason} = error -> error
    end
  end

  def start_service(sprite_name, service_name) do
    maybe_notify({:start_service, sprite_name, service_name})

    case Application.get_env(:platform_phx, :sprite_runtime_start_result, :ok) do
      :ok -> {:ok, %{state: "active"}}
      {:error, _reason} = error -> error
    end
  end

  defp maybe_notify(message) do
    case Application.get_env(:platform_phx, :sprite_runtime_test_pid) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end
  end
end
