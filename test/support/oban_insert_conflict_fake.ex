defmodule PlatformPhx.ObanInsertConflictFake do
  @moduledoc false

  alias Oban.Job

  def insert(_changeset) do
    {:ok, %Job{id: 1, conflict?: true, args: %{"agent_id" => 123}}}
  end
end
