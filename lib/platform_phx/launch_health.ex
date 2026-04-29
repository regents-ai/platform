defmodule PlatformPhx.LaunchHealth do
  @moduledoc false

  alias PlatformPhx.Repo

  @spec snapshot() :: %{status: String.t(), checks: map()}
  def snapshot do
    checks = %{
      database: database_status(),
      cache: cache_status()
    }

    %{
      status: overall_status(checks),
      checks: checks
    }
  end

  defp database_status do
    case Repo.query("select 1", []) do
      {:ok, _result} -> "ready"
      {:error, _reason} -> "unavailable"
    end
  end

  defp cache_status do
    case PlatformPhx.LocalCache.status() do
      :ready -> "ready"
      {:error, _reason} -> "unavailable"
    end
  end

  defp overall_status(%{database: "ready", cache: "ready"}),
    do: "ready"

  defp overall_status(_checks), do: "unavailable"
end
