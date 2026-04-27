defmodule PlatformPhx.Beta.ReportTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Beta.Report

  test "renders a run sheet section with doctor and smoke results" do
    report =
      Report.run(
        doctor: %{
          status: "pass",
          checks: [%{name: "database", status: "pass", message: "Database is reachable."}]
        },
        smoke: %{
          status: "pass",
          host: "https://platform.example",
          checks: [%{name: "home", status: "pass", message: "Home loaded."}]
        }
      )

    markdown = Report.markdown(report)

    assert markdown =~ "Platform Beta Check"
    assert markdown =~ "| `database` | pass | Database is reachable. |"
    assert markdown =~ "Host: `https://platform.example`"
  end

  test "appends to the canonical launch guide by default" do
    assert String.ends_with?(
             Report.default_run_sheet_path(),
             "/docs/regent-local-and-fly-launch-testing.md"
           )
  end
end
