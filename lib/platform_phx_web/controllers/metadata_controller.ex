defmodule PlatformPhxWeb.MetadataController do
  use PlatformPhxWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"token_id" => token_id}) do
    path = metadata_path(token_id)

    case File.read(path) do
      {:ok, body} ->
        json(conn, Jason.decode!(body))

      {:error, :enoent} ->
        send_resp(conn, :not_found, "Not Found")

      {:error, reason} ->
        raise "unable to read metadata #{path}: #{inspect(reason)}"
    end
  end

  defp metadata_path(token_id) do
    root = Application.fetch_env!(:platform_phx, :token_metadata_root)
    Path.join(root, token_id)
  end
end
