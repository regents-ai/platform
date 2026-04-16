defmodule PlatformPhxWeb.Api.ReportController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.OperatorReports
  alias PlatformPhxWeb.ApiErrors

  def bug(conn, params) do
    params
    |> Map.delete("reporting_agent")
    |> OperatorReports.create_bug_report_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def security(conn, params) do
    params
    |> Map.delete("reporting_agent")
    |> OperatorReports.create_security_report_payload()
    |> then(&ApiErrors.respond(conn, &1))
  end

  def agent_bug(conn, params) do
    params = Map.put(params, "reporting_agent", current_reporting_agent(conn))
    ApiErrors.respond(conn, OperatorReports.create_bug_report_payload(params))
  end

  def agent_security(conn, params) do
    params = Map.put(params, "reporting_agent", current_reporting_agent(conn))
    ApiErrors.respond(conn, OperatorReports.create_security_report_payload(params))
  end

  defp current_reporting_agent(conn) do
    claims = conn.assigns[:current_agent_claims] || %{}

    %{
      "wallet_address" => Map.get(claims, "wallet_address"),
      "chain_id" => Map.get(claims, "chain_id"),
      "registry_address" => Map.get(claims, "registry_address"),
      "token_id" => Map.get(claims, "token_id")
    }
    |> maybe_put("label", nil)
  end

  defp maybe_put(payload, _key, nil), do: payload
  defp maybe_put(payload, key, value), do: Map.put(payload, key, value)
end
