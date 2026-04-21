defmodule PlatformPhxWeb.Api.AgentbookController do
  use PlatformPhxWeb, :controller

  import Plug.Conn

  alias PlatformPhx.Accounts
  alias PlatformPhx.Agentbook
  alias PlatformPhxWeb.ApiErrors

  def create(conn, params) when is_map(params) do
    conn.assigns[:current_agent_claims]
    |> Agentbook.create_session(params, base_url(conn))
    |> normalize_session_response()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def show(conn, %{"id" => session_id}) do
    Agentbook.get_session_for_agent(session_id, conn.assigns[:current_agent_claims])
    |> normalize_session_response()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def submit(conn, %{"id" => session_id, "token" => token, "proof" => proof})
      when is_binary(token) and is_map(proof) do
    with %{} = human <- current_human(conn),
         {:ok, session} <- Agentbook.complete_session(session_id, token, human, proof) do
      ApiErrors.respond(conn, {:ok, %{ok: true, session: session}})
    else
      nil ->
        ApiErrors.error(
          conn,
          {:unauthorized, "Sign in before connecting a human-backed trust record"}
        )

      {:error, reason} ->
        ApiErrors.error(conn, reason)
    end
  end

  def submit(conn, _params) do
    ApiErrors.error(conn, {:bad_request, "The trust approval was missing required data"})
  end

  def lookup(conn, _params) do
    conn.assigns[:current_agent_claims]
    |> Agentbook.lookup_for_agent()
    |> normalize_lookup_response()
    |> then(&ApiErrors.respond(conn, &1))
  end

  defp current_human(conn) do
    conn
    |> get_session(:current_human_id)
    |> Accounts.get_human()
  end

  defp normalize_session_response({:ok, session}), do: {:ok, %{ok: true, session: session}}
  defp normalize_session_response({:error, reason}), do: {:error, reason}

  defp normalize_lookup_response({:ok, result}), do: {:ok, %{ok: true, result: result}}
  defp normalize_lookup_response({:error, reason}), do: {:error, reason}

  defp base_url(conn) do
    %URI{
      scheme: Atom.to_string(conn.scheme),
      host: conn.host,
      port: conn.port
    }
    |> URI.to_string()
  end
end
