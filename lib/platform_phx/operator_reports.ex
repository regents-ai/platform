defmodule PlatformPhx.OperatorReports do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.OperatorReports.BugReport
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
  @max_bug_report_page_size 100

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
    page = normalize_page(page)
    page_size = normalize_page_size(page_size)
    offset = (page - 1) * page_size

    reports =
      BugReport
      |> bug_report_filters(filters, now)
      |> order_by([report], desc: report.created_at, desc: report.id)
      |> offset(^offset)
      |> limit(^(page_size + 1))
      |> Repo.all()

    {entries, remainder} = Enum.split(reports, page_size)

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      has_previous: page > 1,
      has_next: remainder != []
    }
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

  defp normalize_page(page) when is_integer(page) and page > 0, do: page
  defp normalize_page(_page), do: 1

  defp normalize_page_size(page_size) when is_integer(page_size) do
    page_size
    |> max(1)
    |> min(@max_bug_report_page_size)
  end

  defp normalize_page_size(_page_size), do: @default_bug_report_page_size

  defp bug_report_filters(query, filters, now) when is_map(filters) do
    query
    |> maybe_filter_status(Map.get(filters, "status"))
    |> maybe_filter_reporter(Map.get(filters, "reporter"))
    |> maybe_filter_source(Map.get(filters, "source"))
    |> maybe_filter_time_window(Map.get(filters, "time_window"), now)
  end

  defp bug_report_filters(query, _filters, _now), do: query

  defp maybe_filter_status(query, status)
       when status in ["pending", "fixed", "won't fix", "duplicate"] do
    where(query, [report], report.status == ^status)
  end

  defp maybe_filter_status(query, _status), do: query

  defp maybe_filter_reporter(query, "wallet") do
    where(query, [report], not is_nil(report.reporter_wallet_address))
  end

  defp maybe_filter_reporter(query, "public") do
    where(query, [report], is_nil(report.reporter_wallet_address))
  end

  defp maybe_filter_reporter(query, _reporter), do: query

  defp maybe_filter_source(query, source) when source in ["Techtree", "Autolaunch", "CLI"] do
    pattern = "%#{source}%"

    where(
      query,
      [report],
      ilike(fragment("coalesce(?, '')", report.reporter_label), ^pattern) or
        ilike(fragment("coalesce(?, '')", report.summary), ^pattern) or
        ilike(fragment("coalesce(?, '')", report.details), ^pattern)
    )
  end

  defp maybe_filter_source(query, "Website") do
    source_patterns = ["%Techtree%", "%Autolaunch%", "%CLI%"]

    Enum.reduce(source_patterns, query, fn pattern, acc ->
      where(
        acc,
        [report],
        not ilike(fragment("coalesce(?, '')", report.reporter_label), ^pattern) and
          not ilike(fragment("coalesce(?, '')", report.summary), ^pattern) and
          not ilike(fragment("coalesce(?, '')", report.details), ^pattern)
      )
    end)
  end

  defp maybe_filter_source(query, _source), do: query

  defp maybe_filter_time_window(query, time_window, now) do
    seconds =
      case time_window do
        "24h" -> 24 * 60 * 60
        "7d" -> 7 * 24 * 60 * 60
        "30d" -> 30 * 24 * 60 * 60
        _ -> nil
      end

    if seconds do
      since = DateTime.add(now, -seconds, :second)
      where(query, [report], report.created_at >= ^since)
    else
      query
    end
  end

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
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {_field, messages} -> messages end)
    |> List.first("The report payload is invalid")
  end
end
