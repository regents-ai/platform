defmodule PlatformPhx.SpriteRuntimeClientTransitionFake do
  @moduledoc false

  def service_state(_sprite_name, _service_name) do
    {:ok, %{state: next_state()}}
  end

  def stop_service(_sprite_name, _service_name), do: {:ok, %{state: "paused"}}
  def start_service(_sprite_name, _service_name), do: {:ok, %{state: "active"}}

  defp next_state do
    case Application.get_env(:platform_phx, :sprite_runtime_transition_states, []) do
      [state | rest] ->
        Application.put_env(:platform_phx, :sprite_runtime_transition_states, rest)
        state

      [] ->
        "active"
    end
  end
end
