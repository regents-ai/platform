defmodule PlatformPhxWeb.Api.AgentSiwaController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.Siwa

  def nonce(conn, params), do: render_result(conn, Siwa.issue_nonce(params))
  def verify(conn, params), do: render_result(conn, Siwa.verify_session(params))
  def http_verify(conn, params), do: render_result(conn, Siwa.verify_http_request(params))

  defp render_result(conn, {:ok, payload}), do: json(conn, payload)

  defp render_result(conn, {:error, {status, code, message}}) do
    conn
    |> put_status(status)
    |> json(%{
      "ok" => false,
      "error" => %{
        "code" => code,
        "message" => message
      }
    })
  end
end
