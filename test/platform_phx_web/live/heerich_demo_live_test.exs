defmodule PlatformPhxWeb.HeerichDemoLiveTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "heerich demo exposes a small surface index and section anchors", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/heerich-demo")

    assert has_element?(view, "#platform-heerich-demo-index")
    assert has_element?(view, "#platform-heerich-demo-gallery")
    assert has_element?(view, "#platform-heerich-demo-focus-status[aria-live=\"polite\"]")
    assert has_element?(view, "#platform-heerich-demo-focus-status[aria-atomic=\"true\"]")
    assert has_element?(view, "#platform-heerich-demo-atlas")
    assert has_element?(view, "#platform-heerich-demo-lab")
    assert has_element?(view, "#platform-procedural-demo-fill[phx-update=\"ignore\"]")
    assert has_element?(view, "#platform-procedural-demo-style[phx-update=\"ignore\"]")
    assert has_element?(view, "#platform-procedural-demo-scale[phx-update=\"ignore\"]")
    assert has_element?(view, "a[href=\"#platform-heerich-demo-gallery\"]")
    assert has_element?(view, "a[href=\"#platform-heerich-demo-atlas\"]")
    assert has_element?(view, "a[href=\"#platform-heerich-demo-lab\"]")
    assert has_element?(view, "[data-demo-index-note]")
  end

  test "heerich demo live guide follows hovered and selected scene targets", %{conn: conn} do
    {:ok, view, html} = live(conn, "/heerich-demo")

    assert html =~ "Baseline cube"
    assert html =~ "Baseline"

    hover_html =
      render_hook(view, "regent:node_hover", %{
        "target_id" => "demo-explode:crucible"
      })

    assert hover_html =~ "Live guide update: Grouped launch cluster. Crucible."
    assert hover_html =~ "Grouped launch cluster"
    assert hover_html =~ "Crucible"
    assert hover_html =~ "Several linked pieces waking up together from one touch."

    select_html =
      render_hook(view, "regent:node_select", %{
        "target_id" => "demo-restyle:plate"
      })

    assert select_html =~ "Live guide update: Restyle after placement. Restyled plate."
    assert select_html =~ "Restyle after placement"
    assert select_html =~ "Restyled plate"
    assert select_html =~ "Placed geometry changing tone without being rebuilt."
  end
end
