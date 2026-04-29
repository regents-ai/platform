defmodule PlatformPhx.Runners.Codex.EventsTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Runners.Codex.Events

  test "maps streaming stdout and stderr into normalized Codex events" do
    assert [
             %{
               kind: "codex.stdout",
               payload: %{stream: "stdout", output: "implemented\n"}
             },
             %{
               kind: "codex.stderr",
               payload: %{stream: "stderr", output: "warning\n"}
             }
           ] = Events.normalize_result_events(%{stdout: "implemented\n", stderr: "warning\n"})
  end

  test "keeps client supplied normalized events and adds stream events" do
    events = [
      %{
        kind: "codex.step.completed",
        payload: %{step: "tests"}
      }
    ]

    assert [
             %{kind: "codex.step.completed"},
             %{kind: "codex.stdout", payload: %{output: "done\n", stream: "stdout"}}
           ] = Events.normalize_result_events(%{events: events, stdout: "done\n"})
  end
end
