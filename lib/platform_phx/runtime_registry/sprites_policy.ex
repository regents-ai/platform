defmodule PlatformPhx.RuntimeRegistry.SpritesPolicy do
  @moduledoc false

  @default_memory_mb 2_048
  @max_memory_mb 16_384

  def normalize_rate_limit_upgrade_url(nil), do: nil
  def normalize_rate_limit_upgrade_url(""), do: nil

  def normalize_rate_limit_upgrade_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme in ["https", "http"] and is_binary(uri.host) ->
        URI.to_string(%{uri | fragment: nil})

      String.starts_with?(url, "/") ->
        url

      true ->
        nil
    end
  end

  def normalize_rate_limit_upgrade_url(_url), do: nil

  def capacity_attrs(payload, observed_at \\ DateTime.utc_now())

  def capacity_attrs(payload, observed_at) when is_map(payload) do
    %{
      observed_memory_mb:
        integer_value(payload, ["memory_mb", "memoryMb", "ram_mb"], @default_memory_mb),
      observed_storage_bytes: integer_value(payload, ["storage_bytes", "storageBytes"], nil),
      observed_capacity_at: DateTime.truncate(observed_at, :second),
      rate_limit_upgrade_url:
        normalize_rate_limit_upgrade_url(
          first_present(payload, [
            "rate_limit_upgrade_url",
            "rateLimitUpgradeUrl",
            "upgrade_url",
            "upgradeUrl"
          ])
        )
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> clamp_memory()
  end

  def capacity_attrs(_payload, observed_at) do
    capacity_attrs(%{}, observed_at)
  end

  def checkpoint_metadata(metadata \\ %{}) do
    Map.merge(Map.new(metadata), %{
      "checkpoint_kind" => "filesystem",
      "checkpoint_semantics" => "filesystem_rollback_point"
    })
  end

  defp clamp_memory(%{observed_memory_mb: memory_mb} = attrs) when memory_mb > @max_memory_mb do
    %{attrs | observed_memory_mb: @max_memory_mb}
  end

  defp clamp_memory(attrs), do: attrs

  defp first_present(payload, keys) do
    Enum.find_value(keys, fn key -> Map.get(payload, key) end)
  end

  defp integer_value(payload, keys, default) do
    case first_present(payload, keys) do
      value when is_integer(value) -> value
      value when is_binary(value) -> parse_integer(value, default)
      _value -> default
    end
  end

  defp parse_integer(value, default) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _other -> default
    end
  end
end
