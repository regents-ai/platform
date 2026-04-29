defmodule PlatformPhx.Beta.StatusConstraintPreflightTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Beta.StatusConstraintPreflight

  defmodule CleanRepo do
    def query(_sql, [_allowed]), do: {:ok, %{rows: []}}
  end

  defmodule DirtyRepo do
    def query(sql, [_allowed]) do
      if String.contains?(sql, ~s("agent_workers")) do
        {:ok, %{rows: [["sleeping", 2]]}}
      else
        {:ok, %{rows: []}}
      end
    end
  end

  defmodule ErrorRepo do
    def query(_sql, [_allowed]), do: {:error, :database_unavailable}
  end

  test "passes when every current status value matches the release constraints" do
    assert {:ok, []} = StatusConstraintPreflight.run(CleanRepo)
  end

  test "reports invalid values without changing the database" do
    assert {:ok, [issue]} = StatusConstraintPreflight.run(DirtyRepo)

    assert issue == %{
             table: "agent_workers",
             column: "status",
             invalid_values: [%{value: "sleeping", count: 2}]
           }
  end

  test "returns database errors to the release doctor" do
    assert {:error, :database_unavailable} = StatusConstraintPreflight.run(ErrorRepo)
  end
end
