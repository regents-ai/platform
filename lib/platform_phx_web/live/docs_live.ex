defmodule PlatformPhxWeb.DocsLive do
  use PlatformPhxWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Docs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="docs"
      header_eyebrow="Docs"
      header_title="Docs"
      theme_class="rg-regent-theme-platform"
    >
      <div id="platform-docs-shell" class="pp-route-shell rg-regent-theme-platform">
        <div class="pp-route-stage">
          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-product-panel pp-product-panel--feature">
              <p class="pp-home-kicker">Start here</p>
              <h2 class="pp-route-panel-title">
                Use this page when you want the short version of the Regent story.
              </h2>
              <p class="pp-panel-copy max-w-[48rem]">
                The website is for guided setup and company launch. Regents CLI is for local work, repeatable runs, and machine-driven tasks.
              </p>
              <div class="pp-link-row">
                <.link navigate={~p"/app"} class="pp-link-button pp-link-button-slim">
                  App setup <span aria-hidden="true">→</span>
                </.link>
                <.link
                  navigate={~p"/cli"}
                  class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                >
                  View CLI <span aria-hidden="true">→</span>
                </.link>
              </div>
            </article>

            <article class="pp-route-panel pp-product-panel">
              <p class="pp-home-kicker">What this covers</p>
              <h2 class="pp-route-panel-title">
                The four places people usually move through
              </h2>
              <ul class="pp-fact-list">
                <li>The app for access, identity, billing, company opening, and progress.</li>
                <li>The public company page after launch.</li>
                <li>Regents CLI for Techtree, Autolaunch, and repeatable terminal work.</li>
                <li>Techtree and Autolaunch as the two next product lanes after formation.</li>
              </ul>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel">
              <p class="pp-home-kicker">When to use the website</p>
              <h2 class="pp-route-panel-title">
                Stay here when the task is about access, setup, billing, or launch.
              </h2>
              <p class="pp-panel-copy">
                Start in the app, move through access, identity, billing, and company opening, then use the public company page once the company is live.
              </p>
            </article>

            <article class="pp-route-panel">
              <p class="pp-home-kicker">When to use the CLI</p>
              <h2 class="pp-route-panel-title">
                Switch to Regents CLI when the work starts on your machine.
              </h2>
              <p class="pp-panel-copy">
                Techtree and Autolaunch both live better on a machine when the next step needs local files or repeatable commands.
              </p>
            </article>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
