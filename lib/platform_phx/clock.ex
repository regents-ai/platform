defmodule PlatformPhx.Clock do
  @moduledoc false

  def utc_now, do: DateTime.utc_now()

  def now, do: utc_now() |> DateTime.truncate(:second)

  def unix_seconds, do: System.system_time(:second)

  def add(%DateTime{} = datetime, amount, unit), do: DateTime.add(datetime, amount, unit)
end
