defmodule PlatformPhx.OperatorReports do
  @moduledoc false

  alias PlatformPhx.OperatorReports.BugReport
  alias PlatformPhx.OperatorReports.BugReports
  alias PlatformPhx.OperatorReports.SecurityReport
  alias PlatformPhx.Repo

  @type reason ::
          {:bad_request, String.t()}
          | {:conflict, String.t()}
  @type bug_report_page :: %{
          entries: [BugReport.t()],
          page: pos_integer(),
          page_size: pos_integer(),
          has_previous: boolean(),
          has_next: boolean()
        }

  @public_bug_report_url "https://regents.sh/bug-report"
  @default_bug_report_page_size 50

  @spec public_bug_report_url() :: String.t()
  def public_bug_report_url, do: @public_bug_report_url

  @spec create_bug_report_payload(map()) :: {:ok, map()} | {:error, reason()}
  def create_bug_report_payload(params) do
    with {:ok, report} <- create_bug_report(params) do
      {:ok,
       %{
         "ok" => true,
         "message" =>
           "Your report was saved. Its status will appear at #{@public_bug_report_url}.",
         "public_url" => @public_bug_report_url,
         "report" => bug_report_payload(report)
       }}
    end
  end

  @spec create_security_report_payload(map()) :: {:ok, map()} | {:error, reason()}
  def create_security_report_payload(params) do
    with {:ok, report} <- create_security_report(params) do
      {:ok,
       %{
         "ok" => true,
         "message" => "Your security report was saved. Keep the report id for private follow-up.",
         "report" => security_report_payload(report)
       }}
    end
  end

  @spec list_bug_reports() :: [BugReport.t()]
  def list_bug_reports do
    list_bug_reports_page(1, @default_bug_report_page_size).entries
  end

  @spec list_bug_reports_page(integer(), integer()) :: bug_report_page()
  def list_bug_reports_page(page, page_size \\ @default_bug_report_page_size) do
    list_bug_reports_page(page, page_size, %{}, DateTime.utc_now())
  end

  @spec list_bug_reports_page(integer(), integer(), map(), DateTime.t()) :: bug_report_page()
  def list_bug_reports_page(page, page_size, filters, now) do
    BugReports.list_page(page, page_size, filters, now)
  end

  @spec get_bug_report(pos_integer()) :: BugReport.t() | nil
  def get_bug_report(id) when is_integer(id) and id > 0, do: Repo.get(BugReport, id)
  def get_bug_report(_id), do: nil

  @spec create_bug_report(map()) :: {:ok, BugReport.t()} | {:error, reason()}
  def create_bug_report(params) when is_map(params) do
    %BugReport{}
    |> BugReport.changeset(bug_report_attrs(params))
    |> Repo.insert()
    |> translate_write_result()
  end

  def create_bug_report(_params),
    do: {:error, {:bad_request, "Bug report payload must be a JSON object"}}

  @spec create_security_report(map()) :: {:ok, SecurityReport.t()} | {:error, reason()}
  def create_security_report(params) when is_map(params) do
    %SecurityReport{}
    |> SecurityReport.changeset(security_report_attrs(params))
    |> Repo.insert()
    |> translate_write_result()
  end

  def create_security_report(_params),
    do: {:error, {:bad_request, "Security report payload must be a JSON object"}}

  @spec bug_report_payload(BugReport.t()) :: map()
  def bug_report_payload(%BugReport{} = report) do
    %{
      "report_id" => report.report_id,
      "summary" => report.summary,
      "details" => report.details,
      "status" => report.status,
      "reporting_agent" => reporting_agent_payload(report),
      "created_at" => iso_datetime(report.created_at)
    }
  end

  @spec security_report_payload(SecurityReport.t()) :: map()
  def security_report_payload(%SecurityReport{} = report) do
    %{
      "report_id" => report.report_id,
      "summary" => report.summary,
      "details" => report.details,
      "contact" => report.contact,
      "reporting_agent" => reporting_agent_payload(report),
      "created_at" => iso_datetime(report.created_at)
    }
  end

  defp bug_report_attrs(params) do
    reporting_agent = Map.get(params, "reporting_agent")

    %{
      summary: Map.get(params, "summary"),
      details: Map.get(params, "details"),
      status: "pending",
      reporter_wallet_address: agent_field(reporting_agent, "wallet_address"),
      reporter_chain_id: agent_field(reporting_agent, "chain_id"),
      reporter_registry_address: agent_field(reporting_agent, "registry_address"),
      reporter_token_id: agent_field(reporting_agent, "token_id"),
      reporter_label: agent_field(reporting_agent, "label")
    }
  end

  defp security_report_attrs(params) do
    reporting_agent = Map.get(params, "reporting_agent")

    %{
      summary: Map.get(params, "summary"),
      details: Map.get(params, "details"),
      contact: Map.get(params, "contact"),
      reporter_wallet_address: agent_field(reporting_agent, "wallet_address"),
      reporter_chain_id: agent_field(reporting_agent, "chain_id"),
      reporter_registry_address: agent_field(reporting_agent, "registry_address"),
      reporter_token_id: agent_field(reporting_agent, "token_id"),
      reporter_label: agent_field(reporting_agent, "label")
    }
  end

  defp agent_field(reporting_agent, key) when is_map(reporting_agent),
    do: Map.get(reporting_agent, key)

  defp agent_field(_reporting_agent, _key), do: nil

  defp reporting_agent_payload(report) do
    payload =
      %{
        "wallet_address" => report.reporter_wallet_address,
        "chain_id" => report.reporter_chain_id,
        "registry_address" => report.reporter_registry_address,
        "token_id" => report.reporter_token_id
      }
      |> maybe_put("label", report.reporter_label)

    if Enum.any?(payload, fn {_key, value} -> not is_nil(value) end), do: payload, else: nil
  end

  defp iso_datetime(nil), do: nil
  defp iso_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp maybe_put(payload, _key, nil), do: payload
  defp maybe_put(payload, _key, ""), do: payload
  defp maybe_put(payload, key, value), do: Map.put(payload, key, value)

  defp translate_write_result({:ok, report}), do: {:ok, report}

  defp translate_write_result({:error, changeset}) do
    if Keyword.has_key?(changeset.errors, :report_id) do
      {:error, {:conflict, "A duplicate report id was generated. Please retry the request."}}
    else
      {:error, {:bad_request, first_changeset_error(changeset)}}
    end
  end

  defp first_changeset_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> changeset_error_opt(key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {_field, messages} -> messages end)
    |> List.first("The report payload is invalid")
  end

  defp changeset_error_opt(opts, key) do
    Enum.find_value(opts, key, fn
      {opt_key, value} when is_atom(opt_key) ->
        if Atom.to_string(opt_key) == key, do: value

      {^key, value} ->
        value

      _other ->
        nil
    end)
  end
end
