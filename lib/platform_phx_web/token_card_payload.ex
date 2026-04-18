defmodule PlatformPhxWeb.TokenCardPayload do
  @moduledoc false

  def encode(entry) when is_map(entry) do
    entry
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end
end
