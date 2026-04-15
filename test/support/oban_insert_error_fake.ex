defmodule PlatformPhx.ObanInsertErrorFake do
  @moduledoc false

  def insert(_changeset), do: {:error, :queue_unavailable}
end
