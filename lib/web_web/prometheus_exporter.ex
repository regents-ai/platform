defmodule WebWeb.PrometheusExporter do
  @moduledoc """
  Expose Prometheus metrics for the web app.
  """

  use Plug.Router

  plug :match
  plug :dispatch

  get "/metrics" do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("content-type", "text/plain; version=0.0.4; charset=utf-8")
    |> send_resp(
      200,
      TelemetryMetricsPrometheus.Core.scrape(WebWeb.Telemetry.prometheus_reporter())
    )
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
