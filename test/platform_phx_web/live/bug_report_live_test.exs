defmodule PlatformPhxWeb.BugReportLiveTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias PlatformPhx.OperatorReports
  alias PlatformPhx.OperatorReports.BugReport
  alias PlatformPhx.Repo

  @wallet_address "0x1111111111111111111111111111111111111111"
  @registry_address "0x2222222222222222222222222222222222222222"

  test "bug report route renders the empty state", %{conn: conn} do
    {:ok, view, html} = live(conn, "/bug-report")

    assert html =~ "Bug reports and their current status"
    assert html =~ "No reports match this view."
    assert html =~ "Live board"
    assert html =~ "this board shows who sent it"
    assert html =~ ~s(href="/cli")
    assert html =~ ~s(href="/docs")
    assert has_element?(view, "#platform-bug-ledger-empty")
    assert has_element?(view, "#platform-bug-ledger-summary")
  end

  test "bug report route renders reports recent first with details", %{conn: conn} do
    {:ok, older} = create_bug_report("older summary", "older details")
    {:ok, newer} = create_bug_report("newer summary", "newer details")

    Repo.update_all(from(report in BugReport, where: report.id == ^older.id),
      set: [created_at: ~U[2026-04-01 10:00:00Z]]
    )

    Repo.update_all(from(report in BugReport, where: report.id == ^newer.id),
      set: [created_at: ~U[2026-04-01 11:00:00Z]]
    )

    {:ok, view, html} = live(conn, "/bug-report")

    assert html =~ "newer summary"
    assert html =~ "older summary"
    assert html =~ "Show details"
    assert html =~ "newer details"
    assert html =~ "Open"
    assert has_element?(view, "#platform-bug-ledger-stream[phx-update=\"stream\"]")

    assert position(html, "newer summary") < position(html, "older summary")
  end

  test "bug report route replaces the current page with older reports and returns newer", %{
    conn: conn
  } do
    for index <- 1..51 do
      summary = "report-" <> String.pad_leading(Integer.to_string(index), 3, "0")
      {:ok, report} = create_bug_report(summary, "details #{index}")

      Repo.update_all(from(row in BugReport, where: row.id == ^report.id),
        set: [created_at: DateTime.add(~U[2026-04-01 10:00:00Z], index, :second)]
      )
    end

    {:ok, view, html} = live(conn, "/bug-report")

    assert html =~ "Older"
    assert html =~ "Newer"
    assert html =~ "Page 1 shows 50 reports"
    assert html =~ "report-051"
    refute html =~ "report-001"
    assert has_element?(view, "#platform-bug-ledger-stream[phx-update=\"stream\"]")

    older_html =
      view
      |> element("#bug-report-older")
      |> render_click()

    assert older_html =~ "Page 2 shows 1 report"
    assert older_html =~ "report-001"
    refute older_html =~ "report-051"

    newer_html =
      view
      |> element("#bug-report-newer")
      |> render_click()

    assert newer_html =~ "Page 1 shows 50 reports"
    assert newer_html =~ "report-051"
    refute newer_html =~ "report-001"
  end

  test "changing filters resets the report ledger to page one", %{conn: conn} do
    for index <- 1..51 do
      summary = "report-" <> String.pad_leading(Integer.to_string(index), 3, "0")
      {:ok, report} = create_bug_report(summary, "details #{index}")

      Repo.update_all(from(row in BugReport, where: row.id == ^report.id),
        set: [created_at: DateTime.add(~U[2026-04-01 10:00:00Z], index, :second)]
      )
    end

    {:ok, view, _html} = live(conn, "/bug-report")

    view
    |> element("#bug-report-older")
    |> render_click()

    filtered_html =
      view
      |> form("#bug-report-filters", filters: %{"status" => "pending"})
      |> render_change()

    assert filtered_html =~ "Page 1 shows 50 reports"
    assert filtered_html =~ "report-051"
    refute filtered_html =~ "report-001"
  end

  defp create_bug_report(summary, details) do
    OperatorReports.create_bug_report(%{
      "summary" => summary,
      "details" => details,
      "reporting_agent" => %{
        "wallet_address" => @wallet_address,
        "chain_id" => 11_155_111,
        "registry_address" => @registry_address,
        "token_id" => "99",
        "label" => "Hermes operator"
      }
    })
  end

  defp position(haystack, needle) do
    {index, _length} = :binary.match(haystack, needle)
    index
  end
end
