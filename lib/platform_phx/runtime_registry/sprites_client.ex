defmodule PlatformPhx.RuntimeRegistry.SpritesClient do
  @moduledoc false

  alias PlatformPhx.ExternalHttpClient
  alias PlatformPhx.OperatorSecrets.SpriteControlSecret

  @callback list_services(String.t()) :: {:ok, list(map())} | {:error, term()}
  @callback get_service(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback create_service(String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback start_service(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback stop_service(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback service_status(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback service_logs(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback create_runtime(map()) :: {:ok, map()} | {:error, term()}
  @callback get_runtime(String.t()) :: {:ok, map()} | {:error, term()}
  @callback exec(String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback create_checkpoint(String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback restore_checkpoint(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback observe_capacity(String.t()) :: {:ok, map()} | {:error, term()}

  def list_services(runtime_id), do: client().list_services(runtime_id)
  def get_service(runtime_id, service_name), do: client().get_service(runtime_id, service_name)
  def create_service(runtime_id, attrs), do: client().create_service(runtime_id, attrs)

  def start_service(runtime_id, service_name),
    do: client().start_service(runtime_id, service_name)

  def stop_service(runtime_id, service_name), do: client().stop_service(runtime_id, service_name)

  def service_status(runtime_id, service_name),
    do: client().service_status(runtime_id, service_name)

  def service_logs(runtime_id, service_name, opts \\ %{}),
    do: client().service_logs(runtime_id, service_name, opts)

  def service_state(runtime_id, service_name) do
    with {:ok, service} <- service_status(runtime_id, service_name) do
      {:ok, %{state: normalize_service_state(service), raw: service}}
    end
  end

  def create_runtime(attrs), do: client().create_runtime(attrs)
  def get_runtime(runtime_id), do: client().get_runtime(runtime_id)
  def create_sprite(attrs), do: create_runtime(attrs)
  def get_sprite(sprite_name), do: get_runtime(sprite_name)
  def exec(runtime_id, attrs), do: client().exec(runtime_id, attrs)
  def create_checkpoint(runtime_id, attrs), do: client().create_checkpoint(runtime_id, attrs)

  def restore_checkpoint(runtime_id, checkpoint_ref),
    do: client().restore_checkpoint(runtime_id, checkpoint_ref)

  def observe_capacity(runtime_id), do: client().observe_capacity(runtime_id)

  defp normalize_service_state(nil), do: "paused"

  defp normalize_service_state(service) when is_map(service) do
    cond do
      service["state"] in ["running", "active", "started"] -> "active"
      service["status"] in ["running", "active", "started"] -> "active"
      service["running"] == true -> "active"
      true -> "paused"
    end
  end

  def client do
    Application.get_env(:platform_phx, :runtime_registry_sprites_client, __MODULE__.HttpClient)
  end

  defmodule HttpClient do
    @moduledoc false

    @behaviour PlatformPhx.RuntimeRegistry.SpritesClient

    @impl true
    def list_services(runtime_id) do
      with {:ok, body} <- request(:get, "/v1/sprites/#{runtime_id}/services") do
        {:ok, Map.get(body, "services", body) |> List.wrap()}
      end
    end

    @impl true
    def get_service(runtime_id, service_name) do
      request(:get, "/v1/sprites/#{runtime_id}/services/#{service_name}")
    end

    @impl true
    def create_service(runtime_id, attrs) do
      request(:post, "/v1/sprites/#{runtime_id}/services", json: attrs)
    end

    @impl true
    def start_service(runtime_id, service_name) do
      request(:post, "/v1/sprites/#{runtime_id}/services/#{service_name}/start", json: %{})
    end

    @impl true
    def stop_service(runtime_id, service_name) do
      request(:post, "/v1/sprites/#{runtime_id}/services/#{service_name}/stop", json: %{})
    end

    @impl true
    def service_status(runtime_id, service_name) do
      request(:get, "/v1/sprites/#{runtime_id}/services/#{service_name}")
    end

    @impl true
    def service_logs(runtime_id, service_name, opts) do
      query =
        opts
        |> Map.take(["cursor"])

      request(:get, "/v1/sprites/#{runtime_id}/services/#{service_name}/logs", params: query)
    end

    @impl true
    def create_runtime(attrs) do
      sprite_name = Map.get(attrs, "name")

      if is_binary(sprite_name) and sprite_name != "" do
        request(:post, "/v1/sprites", json: attrs)
      else
        {:error, {:bad_request, "Sprite name is required"}}
      end
    end

    @impl true
    def get_runtime(runtime_id) do
      request(:get, "/v1/sprites/#{runtime_id}")
    end

    @impl true
    def exec(runtime_id, attrs) do
      request(:post, "/v1/sprites/#{runtime_id}/exec", json: attrs)
    end

    @impl true
    def create_checkpoint(runtime_id, attrs) do
      request(:post, "/v1/sprites/#{runtime_id}/checkpoints", json: attrs)
    end

    @impl true
    def restore_checkpoint(runtime_id, checkpoint_ref) do
      request(:post, "/v1/sprites/#{runtime_id}/checkpoints/#{checkpoint_ref}/restore", json: %{})
    end

    @impl true
    def observe_capacity(runtime_id) do
      request(:get, "/v1/sprites/#{runtime_id}")
    end

    defp request(method, path, opts \\ []) do
      with {:ok, token} <- SpriteControlSecret.fetch_token(),
           {:ok, response} <-
             ExternalHttpClient.request(
               [method: method, url: base_url() <> path, headers: headers(token)] ++ opts
             ),
           true <- response.status in 200..299 do
        {:ok, response.body || %{}}
      else
        false ->
          {:error, {:external, :sprites, "Sprites request failed"}}

        {:error, reason} ->
          {:error, {:external, :sprites, ExternalHttpClient.format_error(reason)}}

        error ->
          error
      end
    end

    defp base_url do
      :platform_phx
      |> Application.get_env(:sprites_api_base_url, "https://api.sprites.dev")
      |> String.trim_trailing("/")
    end

    defp headers(token),
      do: [{"authorization", "Bearer #{token}"}, {"accept", "application/json"}]
  end
end
