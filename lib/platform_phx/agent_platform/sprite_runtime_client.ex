defmodule PlatformPhx.AgentPlatform.SpriteRuntimeClient do
  @moduledoc false

  alias PlatformPhx.OperatorSecrets.SpriteControlSecret

  def service_state(sprite_name, service_name) do
    client().service_state(sprite_name, service_name)
  end

  def stop_service(sprite_name, service_name) do
    client().stop_service(sprite_name, service_name)
  end

  def start_service(sprite_name, service_name) do
    client().start_service(sprite_name, service_name)
  end

  def client do
    Application.get_env(:platform_phx, :sprite_runtime_client, __MODULE__.HttpClient)
  end

  defmodule HttpClient do
    @moduledoc false

    def service_state(sprite_name, service_name) do
      with {:ok, token} <- fetch_token(),
           {:ok, %{status: status, body: body}} <-
             Req.get("https://api.sprites.dev/v1/sprites/#{sprite_name}/services",
               headers: [{"authorization", "Bearer #{token}"}]
             ),
           true <- status in 200..299 do
        services = Map.get(body, "services", body)
        service = Enum.find(List.wrap(services), &(Map.get(&1, "name") == service_name))

        {:ok, %{state: normalize_service_state(service), raw: service}}
      else
        false ->
          {:error, {:external, :sprite, "Sprites service lookup failed"}}

        {:error, error} ->
          {:error, {:external, :sprite, format_error(error)}}

        error ->
          error
      end
    end

    def stop_service(sprite_name, service_name) do
      case post_service_action(sprite_name, service_name, "stop") do
        :ok -> {:ok, %{state: "paused"}}
        {:error, _reason} = error -> error
      end
    end

    def start_service(sprite_name, service_name) do
      case post_service_action(sprite_name, service_name, "start") do
        :ok -> {:ok, %{state: "active"}}
        {:error, _reason} = error -> error
      end
    end

    defp post_service_action(sprite_name, service_name, action) do
      with {:ok, token} <- fetch_token(),
           {:ok, %{status: status}} <-
             Req.post(
               "https://api.sprites.dev/v1/sprites/#{sprite_name}/services/#{service_name}/#{action}",
               headers: [{"authorization", "Bearer #{token}"}]
             ),
           true <- status in 200..299 do
        :ok
      else
        false -> {:error, {:external, :sprite, "Sprites #{action} failed"}}
        {:error, error} -> {:error, {:external, :sprite, format_error(error)}}
        error -> error
      end
    end

    defp normalize_service_state(nil), do: "paused"

    defp normalize_service_state(service) when is_map(service) do
      cond do
        service["state"] in ["running", "active", "started"] -> "active"
        service["status"] in ["running", "active", "started"] -> "active"
        service["running"] == true -> "active"
        true -> "paused"
      end
    end

    defp fetch_token do
      SpriteControlSecret.fetch_token()
    end

    defp format_error(%{__exception__: true} = error), do: Exception.message(error)
    defp format_error({_kind, message}) when is_binary(message), do: message
    defp format_error(error), do: inspect(error)
  end
end
