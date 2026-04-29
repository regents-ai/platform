defmodule PlatformPhx.LocalCache do
  @moduledoc false

  @cache_name :platform_cache

  def child_spec, do: RegentCache.child_spec(@cache_name)
  def status, do: RegentCache.status(@cache_name)
  def fetch(key, ttl_seconds, fun), do: RegentCache.fetch(@cache_name, key, ttl_seconds, fun)
  def delete(keys), do: RegentCache.delete(@cache_name, keys)
end
