defmodule PlatformPhx.Dragonfly do
  @moduledoc false

  @spec enabled?() :: boolean()
  def enabled?, do: RegentCache.Dragonfly.enabled?(:platform_phx)

  @spec status() :: :disabled | :ready | {:error, term()}
  def status, do: RegentCache.Dragonfly.status(:platform_phx)

  @spec command([term()]) :: {:ok, term()} | {:error, term()}
  def command(command), do: RegentCache.Dragonfly.command(:platform_phx, command)

  @spec get(String.t()) :: {:ok, String.t() | nil} | {:error, term()}
  def get(key), do: RegentCache.Dragonfly.get(:platform_phx, key)

  @spec set(String.t(), String.t(), pos_integer()) :: :ok | {:error, term()}
  def set(key, value, ttl_seconds),
    do: RegentCache.Dragonfly.set(:platform_phx, key, value, ttl_seconds)

  @spec delete(String.t() | [String.t()]) :: :ok | {:error, term()}
  def delete(keys), do: RegentCache.Dragonfly.delete(:platform_phx, keys)
end
