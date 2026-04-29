defmodule PlatformPhx.Runners.Codex.CommandRunnerTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Runners.Codex.CommandRunner

  test "captures stdout and stderr separately" do
    assert {:ok, result} =
             CommandRunner.run("sh", ["-c", "cat && echo warning >&2"],
               cd: System.tmp_dir!(),
               input: "ok\n"
             )

    assert result.exit_status == 0
    assert result.stdout == "ok\n"
    assert result.stderr == "warning\n"
  end

  test "returns nonzero status with captured stderr" do
    assert {:ok, result} =
             CommandRunner.run("sh", ["-c", "echo failed >&2; exit 7"],
               cd: System.tmp_dir!(),
               input: ""
             )

    assert result.exit_status == 7
    assert result.stdout == ""
    assert result.stderr == "failed\n"
  end
end
