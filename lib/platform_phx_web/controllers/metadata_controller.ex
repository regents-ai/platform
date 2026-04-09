defmodule PlatformPhxWeb.MetadataController do
  use PlatformPhxWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"token_id" => token_id}) do
    path = metadata_path(token_id)

    case File.read(path) do
      {:ok, body} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      {:error, :enoent} ->
        send_resp(conn, :not_found, "Not Found")

      {:error, reason} ->
        raise "unable to read metadata #{path}: #{inspect(reason)}"
    end
  end

  defp metadata_path(token_id) do
    Path.expand("priv/metadata/#{token_id}", File.cwd!())
  end
end
