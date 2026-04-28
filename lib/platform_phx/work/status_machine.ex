defmodule PlatformPhx.Work.StatusMachine do
  @moduledoc false

  def work_item_statuses, do: ["draft", "ready", "running", "blocked", "completed", "canceled"]
  def work_goal_statuses, do: ["draft", "active", "paused", "completed", "canceled"]

  def work_run_statuses,
    do: ["queued", "running", "waiting_for_approval", "completed", "failed", "canceled"]
end
