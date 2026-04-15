defmodule PlatformPhxWeb.RequireSessionCsrf do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  @unprotected_methods ~w(GET HEAD OPTIONS)

  def init(opts), do: opts

  def call(%Plug.Conn{method: method} = conn, _opts) when method in @unprotected_methods,
    do: conn

  def call(conn, _opts) do
    csrf_state =
      conn
      |> get_session("_csrf_token")
      |> Plug.CSRFProtection.dump_state_from_session()

    request_token =
      conn
      |> get_req_header("x-csrf-token")
      |> List.first()

    if Plug.CSRFProtection.valid_state_and_csrf_token?(csrf_state, request_token) do
      conn
    else
      raise Plug.CSRFProtection.InvalidCSRFTokenError
    end
  end
end
