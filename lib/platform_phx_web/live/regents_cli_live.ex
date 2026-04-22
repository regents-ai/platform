defmodule PlatformPhxWeb.RegentCliLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.RegentCliCatalog
  alias PlatformPhxWeb.RegentCliPage

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Regents CLI")
     |> assign(:intro, RegentCliCatalog.intro())
     |> assign(:hero_highlights, RegentCliCatalog.hero_highlights())
     |> assign(:hero_quick_start_steps, RegentCliCatalog.hero_quick_start_steps())
     |> assign(:quick_start_note, RegentCliCatalog.quick_start_note())
     |> assign(:techtree_start_intro, RegentCliCatalog.techtree_start_intro())
     |> assign(:best_first_marks, RegentCliCatalog.best_first_marks())
     |> assign(:work_loop, RegentCliCatalog.work_loop())
     |> assign(:common_rule_cards, RegentCliCatalog.common_rule_cards())
     |> assign(:command_tiles, RegentCliCatalog.command_tiles())
     |> assign(:guidance_cards, RegentCliCatalog.guidance_cards())
     |> assign(:page_markdown, RegentCliPage.page_markdown())}
  end

  @impl true
  def render(assigns), do: RegentCliPage.page(assigns)
end
