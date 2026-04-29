defmodule PlatformPhx.OperatorSecrets.SpriteControlSecret do
  @moduledoc false
  use GenServer

  import Bitwise

  @type state :: %{
          token: String.t(),
          path: String.t(),
          loaded_at: DateTime.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec fetch_token() :: {:ok, String.t()} | {:error, {:unavailable, String.t()}}
  def fetch_token do
    GenServer.call(__MODULE__, :fetch_token)
  catch
    :exit, {:noproc, _reason} ->
      {:error, {:unavailable, "Sprite control secret service is not running"}}
  end

  @spec reload() :: :ok | {:error, {:unavailable, String.t()}}
  def reload do
    GenServer.call(__MODULE__, :reload)
  catch
    :exit, {:noproc, _reason} ->
      {:error, {:unavailable, "Sprite control secret service is not running"}}
  end

  @impl true
  def init(_opts) do
    case load_state() do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:fetch_token, _from, %{token: token} = state) do
    {:reply, {:ok, token}, state}
  end

  def handle_call(:fetch_token, _from, state) do
    {:reply, {:error, {:unavailable, "Sprite control secret is not loaded"}}, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case load_state() do
      {:ok, next_state} -> {:reply, :ok, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp load_state do
    case config_token() do
      token when is_binary(token) and token != "" ->
        {:ok, %{token: token, path: "config", loaded_at: now()}}

      _other ->
        with {:ok, path} <- fetch_secret_path(),
             :ok <- validate_secret_permissions(path),
             {:ok, token} <- read_secret(path) do
          {:ok, %{token: token, path: path, loaded_at: now()}}
        end
    end
  end

  defp config_token do
    Application.get_env(:platform_phx, __MODULE__, [])
    |> Keyword.get(:token)
  end

  defp fetch_secret_path do
    case PlatformPhx.RuntimeConfig.sprites_api_token_file() do
      nil ->
        {:error, {:unavailable, "Server missing SPRITES_API_TOKEN_FILE"}}

      path ->
        {:ok, path}
    end
  end

  defp validate_secret_permissions(path) do
    if validate_permissions?() do
      case File.stat(path) do
        {:ok, %{type: :regular, mode: mode}} ->
          if (mode &&& 0o077) == 0 do
            :ok
          else
            {:error,
             {:unavailable, "Sprite control secret file must not be readable by group or world"}}
          end

        {:ok, _stat} ->
          {:error, {:unavailable, "Sprite control secret path must be a regular file"}}

        {:error, :enoent} ->
          {:error, {:unavailable, "Sprite control secret file not found"}}

        {:error, reason} ->
          {:error, {:unavailable, "Sprite control secret file error: #{inspect(reason)}"}}
      end
    else
      case File.stat(path) do
        {:ok, %{type: :regular}} ->
          :ok

        {:ok, _stat} ->
          {:error, {:unavailable, "Sprite control secret path must be a regular file"}}

        {:error, :enoent} ->
          {:error, {:unavailable, "Sprite control secret file not found"}}

        {:error, reason} ->
          {:error, {:unavailable, "Sprite control secret file error: #{inspect(reason)}"}}
      end
    end
  end

  defp validate_permissions? do
    Application.get_env(:platform_phx, __MODULE__, [])
    |> Keyword.get(:validate_permissions?, true)
  end

  defp read_secret(path) do
    case File.read(path) do
      {:ok, contents} ->
        token = String.trim(contents)

        if token == "" do
          {:error, {:unavailable, "Sprite control secret file is empty"}}
        else
          {:ok, token}
        end

      {:error, reason} ->
        {:error, {:unavailable, "Sprite control secret read failed: #{inspect(reason)}"}}
    end
  end

  defp now, do: PlatformPhx.Clock.now()
end
