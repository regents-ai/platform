defmodule PlatformPhx.LaunchHealth do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.Repo

  @spec snapshot() :: %{status: String.t(), checks: map(), launch: map()}
  def snapshot do
    checks = %{
      database: database_status(),
      cache: cache_status()
    }

    %{
      status: overall_status(checks),
      checks: checks,
      launch: launch_counts()
    }
  end

  defp database_status do
    case Repo.query("select 1", []) do
      {:ok, _result} -> "ready"
      {:error, _reason} -> "unavailable"
    end
  end

  defp cache_status do
    case RegentCache.Dragonfly.status(:platform_phx) do
      :ready -> "ready"
      :disabled -> "disabled"
      {:error, _reason} -> "unavailable"
    end
  end

  defp launch_counts do
    FormationRun
    |> group_by([formation], formation.status)
    |> select([formation], {formation.status, count(formation.id)})
    |> Repo.all()
    |> Map.new()
    |> then(fn counts ->
      %{
        queued: Map.get(counts, "queued", 0),
        running: Map.get(counts, "running", 0),
        failed: Map.get(counts, "failed", 0),
        succeeded: Map.get(counts, "succeeded", 0)
      }
    end)
  end

  defp overall_status(%{database: "ready", cache: cache}) when cache in ["ready", "disabled"],
    do: "ready"

  defp overall_status(_checks), do: "unavailable"
end
