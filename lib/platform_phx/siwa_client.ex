defmodule PlatformPhx.SiwaClient do
  @moduledoc false

  @callback verify_http_request(map(), keyword()) ::
              {:ok, map()} | {:error, {integer(), String.t(), String.t()}}

  def verify_http_request(payload, opts \\ []) when is_map(payload) do
    impl().verify_http_request(payload, opts)
  end

  defp impl do
    Application.get_env(:platform_phx, :siwa_client, PlatformPhx.SiwaClient.Http)
  end
end
