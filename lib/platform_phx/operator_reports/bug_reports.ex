defmodule PlatformPhx.OperatorReports.BugReports do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.OperatorReports.BugReport
  alias PlatformPhx.Repo

  @default_page_size 50
  @max_page_size 100

  @type page :: %{
          entries: [BugReport.t()],
          page: pos_integer(),
          page_size: pos_integer(),
          has_previous: boolean(),
          has_next: boolean()
        }

  @spec list_page(integer(), integer(), map(), DateTime.t()) :: page()
  def list_page(page, page_size \\ @default_page_size, filters \\ %{}, now \\ DateTime.utc_now()) do
    page = normalize_page(page)
    page_size = normalize_page_size(page_size)
    offset = (page - 1) * page_size

    reports =
      BugReport
      |> apply_filters(filters, now)
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

  @spec source(BugReport.t()) :: String.t()
  def source(%BugReport{} = report) do
    text =
      [
        report.reporter_label,
        report.summary,
        report.details
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")
      |> String.downcase()

    cond do
      String.contains?(text, "autolaunch") -> "Autolaunch"
      String.contains?(text, "cli") -> "CLI"
      String.contains?(text, "techtree") -> "Techtree"
      true -> "Website"
    end
  end

  @spec source_totals([BugReport.t()]) :: map()
  def source_totals(reports) when is_list(reports) do
    Enum.reduce(reports, %{}, fn report, totals ->
      Map.update(totals, source(report), 1, &(&1 + 1))
    end)
  end

  @spec within_time_window?(BugReport.t(), String.t(), DateTime.t()) :: boolean()
  def within_time_window?(_report, "all", _now), do: true

  def within_time_window?(%BugReport{} = report, time_window, %DateTime{} = now) do
    seconds =
      case time_window do
        "24h" -> 24 * 60 * 60
        "7d" -> 7 * 24 * 60 * 60
        "30d" -> 30 * 24 * 60 * 60
        _ -> nil
      end

    case {seconds, report.created_at} do
      {nil, _created_at} -> true
      {_limit, nil} -> false
      {limit, created_at} -> DateTime.diff(now, created_at, :second) <= limit
    end
  end

  def within_time_window?(_report, _time_window, _now), do: false

  defp normalize_page(page) when is_integer(page) and page > 0, do: page
  defp normalize_page(_page), do: 1

  defp normalize_page_size(page_size) when is_integer(page_size) do
    page_size
    |> max(1)
    |> min(@max_page_size)
  end

  defp normalize_page_size(_page_size), do: @default_page_size

  defp apply_filters(query, filters, now) when is_map(filters) do
    query
    |> maybe_filter_status(Map.get(filters, "status"))
    |> maybe_filter_reporter(Map.get(filters, "reporter"))
    |> maybe_filter_source(Map.get(filters, "source"))
    |> maybe_filter_time_window(Map.get(filters, "time_window"), now)
  end

  defp apply_filters(query, _filters, _now), do: query

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
end
