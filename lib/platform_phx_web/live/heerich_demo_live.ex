defmodule PlatformPhxWeb.HeerichDemoLive do
  use PlatformPhxWeb, :live_view

  @highlights [
    "Ceiling lattice stays bright while the reading lane stays calm.",
    "Side walls carry the chamber feeling without crowding the copy.",
    "The center stays open for headlines, controls, or long-form pages."
  ]

  @fit_notes [
    "Landing pages with one main message",
    "Product or token pages that need ceremonial framing",
    "Editorial pages that still need obvious actions"
  ]

  @clarity_notes [
    "Headlines and paragraphs stay on normal panels",
    "Buttons and links stay in the middle lane",
    "Dense tables and forms never have to live inside the scene"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Heerich Chamber Study")
     |> assign(:highlights, @highlights)
     |> assign(:fit_notes, @fit_notes)
     |> assign(:clarity_notes, @clarity_notes)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:none}
      show_wallet_control={false}
      theme_class="rg-regent-theme-platform"
      content_class="p-0"
    >
      <section
        id="platform-heerich-shell-route"
        class="pp-heerich-shell-route rg-regent-theme-platform"
      >
        <div
          id="platform-heerich-shell-background"
          class="pp-heerich-shell-background"
          phx-hook="Demo2Tunnel"
          phx-update="ignore"
          data-demo2-layout="shell"
          data-demo2-variant="regent-shell"
          aria-hidden="true"
        >
          <div class="pp-heerich-shell-scene-shell">
            <div
              id="platform-heerich-shell-scene"
              class="pp-heerich-shell-scene"
              data-demo2-scene
            >
            </div>
          </div>
          <div class="pp-heerich-shell-haze" data-demo2-beam></div>
          <div class="pp-heerich-shell-haze pp-heerich-shell-haze-alt" data-demo2-beam></div>
        </div>

        <div id="platform-heerich-shell-content" class="pp-heerich-shell-content">
          <div class="pp-heerich-shell-centerwash" aria-hidden="true"></div>

          <main class="pp-heerich-shell-lane" aria-label="Heerich chamber study">
            <article class="pp-heerich-shell-panel pp-heerich-shell-panel-hero">
              <p class="pp-home-kicker">Heerich chamber study</p>
              <h1 class="pp-home-title">
                A full-page Regent shell with the content held in the middle.
              </h1>
              <p class="pp-home-copy">
                This study keeps the gold lattice on the ceiling and side walls while the center stays quiet enough for real reading, actions, and long-form pages.
              </p>

              <div class="pp-home-chip-row" aria-label="Chamber study traits">
                <span>Gold ceiling grid</span>
                <span>Ink and charcoal walls</span>
                <span>Centered reading lane</span>
              </div>
            </article>

            <section class="pp-heerich-shell-grid" aria-label="Chamber study notes">
              <article class="pp-heerich-shell-panel">
                <p class="pp-home-kicker">What this proves</p>
                <h2 class="pp-route-panel-title">
                  The shell can frame a page without taking it over.
                </h2>
                <ul class="pp-heerich-shell-list">
                  <%= for item <- @highlights do %>
                    <li>{item}</li>
                  <% end %>
                </ul>
              </article>

              <article class="pp-heerich-shell-panel">
                <p class="pp-home-kicker">Best fit</p>
                <h2 class="pp-route-panel-title">
                  Use this look when the page needs ceremony and focus.
                </h2>
                <ul class="pp-heerich-shell-list">
                  <%= for item <- @fit_notes do %>
                    <li>{item}</li>
                  <% end %>
                </ul>
              </article>

              <article class="pp-heerich-shell-panel">
                <p class="pp-home-kicker">What stays clear</p>
                <h2 class="pp-route-panel-title">The middle lane still carries the work.</h2>
                <ul class="pp-heerich-shell-list">
                  <%= for item <- @clarity_notes do %>
                    <li>{item}</li>
                  <% end %>
                </ul>
              </article>
            </section>

            <div class="pp-link-row">
              <.link navigate={~p"/"} class="pp-link-button">
                Back to Regents Home <span aria-hidden="true">→</span>
              </.link>
            </div>
          </main>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
