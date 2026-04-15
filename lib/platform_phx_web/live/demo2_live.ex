defmodule PlatformPhxWeb.Demo2Live do
  use PlatformPhxWeb, :live_view

  @variants [
    %{
      id: "ember-hall",
      eyebrow: "Pass one",
      title: "Wide ember hall",
      description:
        "The closest pass to the reference: broad ceiling, steady side walls, and a centered dark mass that keeps the glow under control.",
      note: "Use this as the baseline read for the other four."
    },
    %{
      id: "split-spine",
      eyebrow: "Pass two",
      title: "Split spine",
      description:
        "The center opening grows wider and the walls stand taller, so the tunnel feels more architectural and less like a stage set.",
      note: "This one pushes the inside-corner effect hardest."
    },
    %{
      id: "low-orbit",
      eyebrow: "Pass three",
      title: "Low orbit",
      description:
        "The camera drops lower and closer, making the ceiling feel heavier and the run toward the horizon more compressed.",
      note: "It trades openness for pressure."
    },
    %{
      id: "white-gate",
      eyebrow: "Pass four",
      title: "White gate",
      description:
        "The far end brightens and the center slit cools off, which makes the depth feel cleaner and more ceremonial.",
      note: "This is the calmest of the five."
    },
    %{
      id: "redline",
      eyebrow: "Pass five",
      title: "Redline",
      description:
        "Longer depth, hotter ceiling lines, and a tighter center gap turn the chamber into something closer to a launch corridor.",
      note: "It is the most aggressive finish in the set."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Demo 2") |> assign(:variants, @variants)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-demo2-shell"
        class="pp-demo2-shell rg-regent-theme-platform"
        phx-hook="DemoReveal"
      >
        <main id="platform-demo2-stage" class="pp-demo2-stage" aria-label="Five tunnel studies">
          <%= for variant <- @variants do %>
            <section
              id={"platform-demo2-panel-#{variant.id}"}
              class="pp-demo2-panel"
              data-demo-block
              aria-labelledby={"platform-demo2-title-#{variant.id}"}
            >
              <article class="pp-demo2-panel-copy">
                <div class="space-y-4">
                  <p class="pp-home-kicker">{variant.eyebrow}</p>
                  <div class="space-y-3">
                    <h1
                      :if={variant.id == "ember-hall"}
                      class="pp-home-title"
                      id={"platform-demo2-title-#{variant.id}"}
                    >
                      {variant.title}
                    </h1>
                    <h2
                      :if={variant.id != "ember-hall"}
                      class="pp-route-panel-title"
                      id={"platform-demo2-title-#{variant.id}"}
                    >
                      {variant.title}
                    </h2>
                    <p :if={variant.id == "ember-hall"} class="pp-home-copy">
                      Five full-height tunnel passes, stacked one after another so you can scroll through the different reads.
                    </p>
                    <p class="pp-panel-copy">{variant.description}</p>
                  </div>
                </div>

                <div class="pp-home-chip-row" aria-label={"#{variant.title} notes"}>
                  <span>One full viewport</span>
                  <span>Scroll to compare</span>
                  <span>Inside corners stay visible</span>
                </div>

                <p class="pp-demo2-note-copy">{variant.note}</p>
              </article>

              <div
                id={"platform-demo2-frame-#{variant.id}"}
                class="pp-demo2-frame"
                phx-hook="Demo2Tunnel"
                phx-update="ignore"
                data-demo2-variant={variant.id}
                role="img"
                aria-label={"#{variant.title} tunnel study"}
              >
                <div class="pp-demo2-scene-shell">
                  <div
                    id={"platform-demo2-scene-#{variant.id}"}
                    class="pp-demo2-scene"
                    data-demo2-scene
                  >
                  </div>
                </div>

                <div class="pp-demo2-haze" aria-hidden="true"></div>
                <div class="pp-demo2-beam pp-demo2-beam-left" data-demo2-beam aria-hidden="true">
                </div>
                <div class="pp-demo2-beam pp-demo2-beam-right" data-demo2-beam aria-hidden="true">
                </div>

                <div class="pp-demo2-monolith" data-demo2-monolith aria-hidden="true">
                  <div class="pp-demo2-monolith-core">
                    <span class="pp-demo2-monolith-slit" data-demo2-slit></span>
                  </div>
                  <div class="pp-demo2-ramp pp-demo2-ramp-left"></div>
                  <div class="pp-demo2-ramp pp-demo2-ramp-right"></div>
                  <div class="pp-demo2-stair-glow"></div>
                </div>
              </div>
            </section>
          <% end %>
        </main>
      </div>
    </Layouts.app>
    """
  end
end
