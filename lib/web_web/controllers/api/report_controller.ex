defmodule WebWeb.Api.ReportController do
  use WebWeb, :controller

  alias Web.OperatorReports
  alias WebWeb.ApiErrors

  def bug(conn, params) do
    ApiErrors.respond(conn, OperatorReports.create_bug_report_payload(params))
  end

  def security(conn, params) do
    ApiErrors.respond(conn, OperatorReports.create_security_report_payload(params))
  end
end
