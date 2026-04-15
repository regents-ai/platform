defmodule PlatformPhx.SpriteRuntimeClientPausedFake do
  @moduledoc false

  def service_state(_sprite_name, _service_name), do: {:ok, %{state: "paused"}}
  def stop_service(_sprite_name, _service_name), do: {:ok, %{state: "paused"}}
  def start_service(_sprite_name, _service_name), do: {:ok, %{state: "active"}}
end
