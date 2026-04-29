defmodule PlatformPhxWeb.ApiErrors do
  @moduledoc false

  use PlatformPhxWeb, :controller

  @type reason ::
          {:bad_request, String.t()}
          | {:not_found, String.t()}
          | {:forbidden, String.t()}
          | {:unauthorized, String.t()}
          | {:conflict, String.t()}
          | {:payment_required, String.t()}
          | {:unavailable, String.t()}
          | {:external, atom(), String.t()}

  @spec respond(Plug.Conn.t(), {:ok, map()} | {:accepted, map()} | {:error, reason()}) ::
          Plug.Conn.t()
  def respond(conn, {:ok, payload}), do: json(conn, payload)
  def respond(conn, {:accepted, payload}), do: conn |> put_status(:accepted) |> json(payload)
  def respond(conn, {:error, reason}), do: error(conn, reason)

  @spec error(Plug.Conn.t(), reason()) :: Plug.Conn.t()
  def error(conn, {:bad_request, message}), do: render_status(conn, :bad_request, message)
  def error(conn, {:not_found, message}), do: render_status(conn, :not_found, message)
  def error(conn, {:forbidden, message}), do: render_status(conn, :forbidden, message)
  def error(conn, {:unauthorized, message}), do: render_status(conn, :unauthorized, message)
  def error(conn, {:conflict, message}), do: render_status(conn, :conflict, message)
  def error(conn, {:payment_required, message}), do: render_status(conn, 402, message)
  def error(conn, {:unavailable, message}), do: render_status(conn, :service_unavailable, message)
  def error(conn, {:external, _source, message}), do: render_status(conn, :bad_gateway, message)

  @spec render_status(Plug.Conn.t(), Plug.Conn.status() | atom(), String.t()) :: Plug.Conn.t()
  def render_status(conn, status, message) do
    status_code = Plug.Conn.Status.code(status)

    conn
    |> put_status(status)
    |> json(%{
      "error" => %{
        "code" => code_for_status(status),
        "product" => "platform",
        "status" => status_code,
        "path" => conn.request_path,
        "request_id" => request_id(conn),
        "message" => message,
        "next_steps" => nil
      }
    })
  end

  defp code_for_status(status) when is_atom(status), do: Atom.to_string(status)

  defp code_for_status(status) do
    status
    |> Plug.Conn.Status.reason_phrase()
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  defp request_id(conn) do
    conn
    |> Plug.Conn.get_resp_header("x-request-id")
    |> List.first()
  end
end
