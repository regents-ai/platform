defmodule PlatformPhx.AntiCruftTest do
  use ExUnit.Case, async: true

  test "production code does not build atoms from strings" do
    matches =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_number} ->
          String.contains?(line, "String.to_atom") or
            String.contains?(line, "String.to_existing_atom")
        end)
        |> Enum.map(fn {line, line_number} -> "#{path}:#{line_number}:#{line}" end)
      end)

    assert matches == []
  end
end
