defmodule PlatformPhxWeb.ApiErrorsTest do
  use PlatformPhxWeb.ConnCase, async: true

  alias PlatformPhxWeb.ApiErrors

  test "renders the product error envelope", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_resp_header("x-request-id", "req_platform_test")
      |> Map.put(:request_path, "/api/test")
      |> ApiErrors.error({:bad_request, "Choose a supported value"})

    assert %{
             "error" => %{
               "code" => "bad_request",
               "product" => "platform",
               "status" => 400,
               "path" => "/api/test",
               "request_id" => "req_platform_test",
               "message" => "Choose a supported value",
               "next_steps" => nil
             }
           } = json_response(conn, 400)
  end
end
