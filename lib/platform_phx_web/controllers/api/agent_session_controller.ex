defmodule PlatformPhxWeb.Api.AgentSessionController do
  use PlatformPhxWeb, :controller

  import Plug.Conn

  @session_key :agent_session
  @session_ttl_seconds 1_800
  @audience "platform"

  def create(conn, _params) do
    claims = conn.assigns[:current_agent_claims] || %{}
    session = build_session(claims)

    conn
    |> configure_session(renew: true)
    |> put_session(@session_key, session)
    |> json(%{ok: true, session: session})
  end

  def show(conn, _params) do
    case current_session(conn) do
      {:ok, session} ->
        json(conn, %{ok: true, session: session})

      :expired ->
        conn
        |> delete_session(@session_key)
        |> json(%{ok: true, session: nil})

      :missing ->
        json(conn, %{ok: true, session: nil})
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(@session_key)
    |> json(%{ok: true})
  end

  defp build_session(claims) do
    now = DateTime.utc_now()
    issued_at = now |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    expires_at =
      now
      |> DateTime.add(@session_ttl_seconds, :second)
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    %{
      session_id: Ecto.UUID.generate(),
      audience: @audience,
      wallet_address: claims["wallet_address"],
      chain_id: claims["chain_id"],
      registry_address: claims["registry_address"],
      token_id: claims["token_id"],
      issued_at: issued_at,
      expires_at: expires_at
    }
  end

  defp current_session(conn) do
    case get_session(conn, @session_key) do
      %{} = session ->
        with {:ok, audience} <- session_value(session, :audience),
             true <- audience == @audience,
             {:ok, expires_at} <- session_expires_at(session),
             :lt <- DateTime.compare(DateTime.utc_now(), expires_at) do
          {:ok, session}
        else
          _ -> :expired
        end

      _ ->
        :missing
    end
  end

  defp session_expires_at(session) when is_map(session) do
    case session_value(session, :expires_at) do
      {:ok, expires_at} ->
        parse_session_expiry(expires_at)

      {:error, :missing} ->
        {:error, :missing}
    end
  end

  defp session_value(session, key) do
    case Map.get(session, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing}
    end
  end

  defp parse_session_expiry(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, value, _offset} -> {:ok, value}
      _ -> {:error, :invalid}
    end
  end
end
