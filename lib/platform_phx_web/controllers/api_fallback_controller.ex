defmodule PlatformPhxWeb.ApiFallbackController do
  @moduledoc false
  use PlatformPhxWeb, :controller

  alias PlatformPhxWeb.ApiErrors

  def call(conn, {:ok, payload}), do: ApiErrors.respond(conn, {:ok, payload})
  def call(conn, {:accepted, payload}), do: ApiErrors.respond(conn, {:accepted, payload})
  def call(conn, {:error, reason}), do: ApiErrors.error(conn, reason)
  def call(conn, reason), do: ApiErrors.error(conn, reason)
end
