defmodule PlatformPhxWeb.Api.ReportController do
  use PlatformPhxWeb, :controller

  action_fallback PlatformPhxWeb.ApiFallbackController

  alias PlatformPhx.OperatorReports
  alias PlatformPhxWeb.ApiErrors
  alias PlatformPhxWeb.ApiRequest

  def bug(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, report_fields()) do
      attrs
      |> OperatorReports.create_bug_report_payload()
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def security(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, security_report_fields()) do
      attrs
      |> OperatorReports.create_security_report_payload()
      |> then(&ApiErrors.respond(conn, &1))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def agent_bug(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, report_fields()) do
      attrs = Map.put(attrs, "reporting_agent", current_reporting_agent(conn))
      ApiErrors.respond(conn, OperatorReports.create_bug_report_payload(attrs))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
  end

  def agent_security(conn, params) do
    with {:ok, attrs} <- ApiRequest.cast(params, security_report_fields()) do
      attrs = Map.put(attrs, "reporting_agent", current_reporting_agent(conn))
      ApiErrors.respond(conn, OperatorReports.create_security_report_payload(attrs))
    else
      {:error, reason} -> ApiErrors.error(conn, reason)
    end
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

  defp report_fields do
    [
      {"summary", :string, required: true},
      {"details", :string, required: true}
    ]
  end

  defp security_report_fields do
    report_fields() ++ [{"contact", :string, []}]
  end
end
