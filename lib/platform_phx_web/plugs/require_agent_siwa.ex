defmodule PlatformPhxWeb.Plugs.RequireAgentSiwa do
  @moduledoc false

  import Plug.Conn

  alias PlatformPhx.Siwa

  def init(opts), do: opts

  def call(conn, _opts) do
    headers =
      conn.req_headers
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        Map.put(acc, String.downcase(key), value)
      end)

    case Siwa.verify_http_request(%{
           "method" => conn.method,
           "path" => conn.request_path,
           "headers" => headers
         }) do
      {:ok, _payload} ->
        case Siwa.current_agent_claims(headers) do
          {:ok, claims} ->
            assign(conn, :current_agent_claims, claims)

          _ ->
            unauthorized(conn)
        end

      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{
      "ok" => false,
      "error" => %{
        "code" => "siwa_auth_denied",
        "message" => "Signed agent authentication failed"
      }
    })
    |> halt()
  end
end
