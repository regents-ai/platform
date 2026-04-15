defmodule PlatformPhxWeb.Demo2LiveTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "demo2 exposes five full-height tunnel passes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/demo2")

    assert has_element?(view, "#platform-demo2-shell")
    assert has_element?(view, "#platform-demo2-stage")
    assert has_element?(view, "#platform-demo2-panel-ember-hall")
    assert has_element?(view, "#platform-demo2-panel-split-spine")
    assert has_element?(view, "#platform-demo2-panel-low-orbit")
    assert has_element?(view, "#platform-demo2-panel-white-gate")
    assert has_element?(view, "#platform-demo2-panel-redline")

    assert has_element?(
             view,
             "#platform-demo2-frame-ember-hall[phx-hook=\"Demo2Tunnel\"][data-demo2-variant=\"ember-hall\"]"
           )

    assert has_element?(
             view,
             "#platform-demo2-frame-white-gate[data-demo2-variant=\"white-gate\"]"
           )

    assert has_element?(view, "#platform-demo2-frame-redline[data-demo2-variant=\"redline\"]")
  end
end
