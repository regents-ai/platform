defmodule PlatformPhxWeb.MetadataController do
  use PlatformPhxWeb, :controller
  require Logger

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"token_id" => token_id}) do
    path = metadata_path(token_id)

    case File.read(path) do
      {:ok, body} ->
        json(conn, Jason.decode!(body))

      {:error, :enoent} ->
        send_resp(conn, :not_found, "Not Found")

      {:error, reason} ->
        Logger.error("metadata read failed #{inspect(%{path: path, reason: reason})}")
        send_resp(conn, :internal_server_error, "Metadata is unavailable right now.")
    end
  end

  defp metadata_path(token_id) do
    root = Application.fetch_env!(:platform_phx, :token_metadata_root)
    Path.join(root, token_id)
  end
end
