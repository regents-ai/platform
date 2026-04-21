defmodule PlatformPhxWeb.Plugs.RequireAgentSiwa do
  @moduledoc false

  import Plug.Conn

  alias PlatformPhx.SiwaClient

  def init(opts), do: opts

  def call(conn, opts) do
    audience = Keyword.get(opts, :audience, "platform")

    headers =
      conn.req_headers
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        Map.put(acc, String.downcase(key), value)
      end)

    case SiwaClient.verify_http_request(
           %{
             "method" => conn.method,
             "path" => conn.request_path,
             "headers" => headers,
             "body" => conn.assigns[:raw_body]
           },
           audience: audience
         ) do
      {:ok, %{"data" => %{"agent_claims" => agent_claims}}} ->
        assign(conn, :current_agent_claims, agent_claims)

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
