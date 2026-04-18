defmodule PlatformPhxWeb.Plugs.RequireAgentSiwa do
  @moduledoc false

  import Plug.Conn

  alias PlatformPhx.Siwa

  def init(opts), do: opts

  def call(conn, opts) do
    audience = Keyword.get(opts, :audience, "platform")

    headers =
      conn.req_headers
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        Map.put(acc, String.downcase(key), value)
      end)

    case Siwa.verify_http_request(
           %{
             "method" => conn.method,
             "path" => conn.request_path,
             "headers" => headers,
             "body" => conn.assigns[:raw_body]
           },
           audience: audience
         ) do
      {:ok, %{"data" => %{"agent_claims" => agent_claims}}} ->
        case Siwa.current_agent_claims(%{
               "sub" => agent_claims["wallet_address"],
               "chain_id" => agent_claims["chain_id"],
               "registry_address" => agent_claims["registry_address"],
               "token_id" => agent_claims["token_id"]
             }) do
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
