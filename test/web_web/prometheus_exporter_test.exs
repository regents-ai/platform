defmodule WebWeb.PrometheusExporterTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test

  test "serves prometheus metrics" do
    :telemetry.execute(
      [:phoenix, :router_dispatch, :stop],
      %{duration: System.convert_time_unit(120, :millisecond, :native)},
      %{route: "/prometheus-test"}
    )

    conn =
      conn(:get, "/metrics")
      |> WebWeb.PrometheusExporter.call(WebWeb.PrometheusExporter.init([]))

    assert conn.status == 200
    assert ["text/plain; version=0.0.4; charset=utf-8"] == get_resp_header(conn, "content-type")
    assert conn.resp_body =~ "web_phoenix_requests_total"
    assert conn.resp_body =~ ~s(route="/prometheus-test")
    assert conn.resp_body =~ "web_phoenix_request_duration_seconds"
  end
end
