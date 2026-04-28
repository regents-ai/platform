defmodule PlatformPhx.Approvals do
  @moduledoc false

  alias PlatformPhx.WorkRuns

  def request(%{work_run_id: nil}), do: {:error, :work_run_required}
  def request(%{"work_run_id" => nil}), do: {:error, :work_run_required}

  def request(attrs) do
    WorkRuns.create_approval_request(attrs)
  end
end
