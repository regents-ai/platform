defmodule PlatformPhxWeb.HeerichDemoLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.HeerichDemoScenes

  @impl true
  def mount(_params, _session, socket) do
    samples = HeerichDemoScenes.samples()
    demo_focus_lookup = demo_focus_lookup(samples)

    {:ok,
     socket
     |> assign(:page_title, "Heerich Demo")
     |> assign(:demo_samples, samples)
     |> assign(:knob_rows, HeerichDemoScenes.knob_rows())
     |> assign(:feature_rows, HeerichDemoScenes.feature_rows())
     |> assign(:primer_rules, HeerichDemoScenes.primer_rules())
     |> assign(:demo_focus_lookup, demo_focus_lookup)
     |> assign(:demo_focus, default_demo_focus(samples, demo_focus_lookup))}
  end

  def handle_event("regent:node_select", %{"target_id" => target_id}, socket) do
    {:noreply,
     assign(socket, :demo_focus, demo_focus_for(socket.assigns.demo_focus_lookup, target_id))}
  end

  def handle_event("regent:node_select", _params, socket), do: {:noreply, socket}

  def handle_event("regent:node_hover", %{"target_id" => target_id}, socket) do
    {:noreply,
     assign(socket, :demo_focus, demo_focus_for(socket.assigns.demo_focus_lookup, target_id))}
  end

  def handle_event(event, _params, socket)
      when event in ["regent:node_hover", "regent:surface_ready"] do
    {:noreply, socket}
  end

  @impl true
  def handle_event("regent:surface_error", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "One of the Heerich demo surfaces could not render in this browser session."
     )}
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
        id="platform-heerich-demo-shell"
        class="pp-demo-shell rg-regent-theme-platform"
        phx-hook="DemoReveal"
      >
        <main id="platform-heerich-demo" class="pp-demo-stage" aria-label="Heerich hover cycle demos">
          <section class="pp-demo-hero" data-demo-block>
            <div class="pp-demo-hero-layout">
              <div class="pp-demo-hero-copy space-y-4">
                <p class="pp-home-kicker">Heerich 0.11.0 Lab</p>
                <div class="space-y-3">
                  <h1 class="pp-home-title">
                    Shared Regent surfaces, carved forms, and procedural scenes.
                  </h1>
                  <p class="pp-home-copy">
                    This page shows the full Heerich 0.11.0 range in Platform: shared Regent surfaces, carved interiors, tapered forms, restyled rails, and a small gallery of procedural shapes.
                  </p>
                </div>

                <div class="pp-home-chip-row" aria-label="Demo rules">
                  <span>Real Regent scenes</span>
                  <span>HoverCycle on scaled geometry</span>
                  <span>Carve and restyle primitives</span>
                  <span>Direct JS procedural gallery</span>
                </div>
              </div>

              <div class="pp-demo-hero-nav">
                <nav
                  class="pp-demo-index"
                  aria-label="Heerich demo sections"
                  id="platform-heerich-demo-index"
                >
                  <a
                    class="pp-demo-index-item"
                    href="#platform-heerich-demo-gallery"
                    data-demo-index-item
                  >
                    <span class="pp-demo-index-kicker">01</span>
                    <span class="pp-demo-index-label">HoverCycle gallery</span>
                    <span class="pp-demo-index-copy">Nine scene samples, grouped by loop style.</span>
                  </a>

                  <a
                    class="pp-demo-index-item"
                    href="#platform-heerich-demo-atlas"
                    data-demo-index-item
                  >
                    <span class="pp-demo-index-kicker">02</span>
                    <span class="pp-demo-index-label">Configuration atlas</span>
                    <span class="pp-demo-index-copy">
                      The controls that shape each break-and-rebuild pass.
                    </span>
                  </a>

                  <a class="pp-demo-index-item" href="#platform-heerich-demo-lab" data-demo-index-item>
                    <span class="pp-demo-index-kicker">03</span>
                    <span class="pp-demo-index-label">Procedural lab</span>
                    <span class="pp-demo-index-copy">Three shapes drawn directly on the page.</span>
                  </a>
                </nav>

                <p class="pp-demo-index-note" data-demo-index-note>
                  The layout stays legible with reduced motion. The page only adds gentle movement when the browser allows it.
                </p>
              </div>
            </div>
          </section>

          <section
            class="pp-demo-grid"
            data-demo-block
            aria-label="Heerich demo cards"
            id="platform-heerich-demo-gallery"
          >
            <%= for sample <- @demo_samples do %>
              <.hover_cycle_demo sample={sample} />
            <% end %>
          </section>

          <section
            class="pp-demo-panel"
            data-demo-block
            id="platform-heerich-demo-focus"
            aria-labelledby="platform-heerich-demo-focus-heading"
          >
            <p
              id="platform-heerich-demo-focus-status"
              class="sr-only"
              aria-live="polite"
              aria-atomic="true"
            >
              Live guide update: {@demo_focus.sample_title}. {@demo_focus.label}. {@demo_focus.watch_for}
            </p>

            <div class="space-y-3">
              <p class="pp-home-kicker">Live guide</p>
              <h2 class="pp-route-panel-title" id="platform-heerich-demo-focus-heading">
                {@demo_focus.sample_title}
              </h2>
              <p class="pp-panel-copy">
                {@demo_focus.description}
              </p>
            </div>

            <div class="pp-demo-focus-grid">
              <div class="rounded-[1.25rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                <p class="pp-home-kicker">Current focus</p>
                <p class="pp-route-panel-title text-[1.15rem]">{@demo_focus.label}</p>
                <p class="pp-panel-copy mt-2">
                  {@demo_focus.note}
                </p>
              </div>

              <div class="rounded-[1.25rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                <p class="pp-home-kicker">What to watch for</p>
                <dl class="grid gap-3 text-sm text-[color:var(--muted-foreground)]">
                  <div>
                    <dt class="font-display text-[0.95rem] text-[color:var(--foreground)]">Study</dt>
                    <dd>{@demo_focus.eyebrow}</dd>
                  </div>
                  <div>
                    <dt class="font-display text-[0.95rem] text-[color:var(--foreground)]">Shape</dt>
                    <dd>{@demo_focus.label}</dd>
                  </div>
                  <div>
                    <dt class="font-display text-[0.95rem] text-[color:var(--foreground)]">
                      Look for
                    </dt>
                    <dd>{@demo_focus.watch_for}</dd>
                  </div>
                </dl>
              </div>
            </div>
          </section>

          <section class="pp-demo-reference" data-demo-block id="platform-heerich-demo-atlas">
            <article class="pp-demo-panel">
              <div class="space-y-3">
                <p class="pp-home-kicker">Configuration atlas</p>
                <h2 class="pp-route-panel-title">What each HoverCycle control changes</h2>
                <p class="pp-panel-copy">
                  The effect is small on purpose. These controls let you tune how dramatic, how fast, and how tightly grouped the break-and-rebuild loop should feel.
                </p>
              </div>

              <div class="pp-table-scroll">
                <table class="rg-table pp-demo-atlas-table">
                  <thead>
                    <tr>
                      <th scope="col">Control</th>
                      <th scope="col">What it changes</th>
                      <th scope="col">Seen on</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {label, meaning, example} <- @knob_rows do %>
                      <tr>
                        <th scope="row">{label}</th>
                        <td>{meaning}</td>
                        <td>{example}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </article>

            <article class="pp-demo-panel">
              <div class="space-y-3">
                <p class="pp-home-kicker">Heerich 0.11.0 additions</p>
                <h2 class="pp-route-panel-title">What the new toolkit opens up</h2>
                <p class="pp-panel-copy">
                  These are the new moves this upgrade adds to the shipped Regent scenes and to the demo page.
                </p>
              </div>

              <div class="pp-table-scroll">
                <table class="rg-table pp-demo-atlas-table">
                  <thead>
                    <tr>
                      <th scope="col">Feature</th>
                      <th scope="col">What it changes</th>
                      <th scope="col">Where it shows up</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {label, meaning, example} <- @feature_rows do %>
                      <tr>
                        <th scope="row">{label}</th>
                        <td>{meaning}</td>
                        <td>{example}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </article>

            <article class="pp-demo-panel">
              <div class="space-y-3">
                <p class="pp-home-kicker">Working rules</p>
                <h2 class="pp-route-panel-title">Use it as scene polish, not hidden state.</h2>
                <p class="pp-panel-copy">
                  HoverCycle should help a surface feel alive, but it should never become the only way someone understands meaning or completes a critical action.
                </p>
              </div>

              <ul class="pp-demo-rule-list">
                <%= for rule <- @primer_rules do %>
                  <li>{rule}</li>
                <% end %>
              </ul>

              <div class="pp-demo-code-grid">
                <article class="pp-demo-code-card">
                  <p class="pp-home-kicker">Turn it on</p>
                  <code class="pp-command">{"hoverCycle: true"}</code>
                </article>

                <article class="pp-demo-code-card">
                  <p class="pp-home-kicker">Group multiple shapes</p>
                  <code class="pp-command">
                    {"hoverCycle: %{\"group\" => \"launch-cluster\", \"mode\" => \"explode\"}"}
                  </code>
                </article>

                <article class="pp-demo-code-card">
                  <p class="pp-home-kicker">Turn it off explicitly</p>
                  <code class="pp-command">{"hoverCycle: %{\"enabled\" => false}"}</code>
                </article>
              </div>
            </article>
          </section>

          <section class="pp-demo-panel" data-demo-block id="platform-heerich-demo-lab">
            <div class="space-y-3">
              <p class="pp-home-kicker">Procedural lab</p>
              <h2 class="pp-route-panel-title">
                Shapes drawn directly on the page
              </h2>
              <p class="pp-panel-copy">
                These three examples show free-form fills, position-based color, and position-based tapering. They sit beside the shared Regent surfaces so you can compare direct drawing with the scene gallery above.
              </p>
            </div>

            <div class="pp-procedural-grid">
              <article class="pp-procedural-card">
                <div class="space-y-2">
                  <p class="pp-home-kicker">Filled volume</p>
                  <h3 class="pp-route-panel-title">Procedural torus shell</h3>
                  <p class="pp-panel-copy">
                    A ring-like shell drawn as one continuous volume instead of being assembled from separate blocks.
                  </p>
                </div>
                <div
                  id="platform-procedural-demo-fill"
                  class="pp-procedural-canvas"
                  phx-hook="HeerichProceduralDemo"
                  phx-update="ignore"
                  data-demo-kind="fill"
                >
                </div>
              </article>

              <article class="pp-procedural-card">
                <div class="space-y-2">
                  <p class="pp-home-kicker">Position-based color</p>
                  <h3 class="pp-route-panel-title">Spectral block</h3>
                  <p class="pp-panel-copy">
                    Color shifts across the block as the shape moves through space, so the surface reads as a gradient built from the form itself.
                  </p>
                </div>
                <div
                  id="platform-procedural-demo-style"
                  class="pp-procedural-canvas"
                  phx-hook="HeerichProceduralDemo"
                  phx-update="ignore"
                  data-demo-kind="style"
                >
                </div>
              </article>

              <article class="pp-procedural-card">
                <div class="space-y-2">
                  <p class="pp-home-kicker">Position-based taper</p>
                  <h3 class="pp-route-panel-title">Tapered tower</h3>
                  <p class="pp-panel-copy">
                    The tower narrows as it rises, which creates a stepped taper without having to place each layer by hand.
                  </p>
                </div>
                <div
                  id="platform-procedural-demo-scale"
                  class="pp-procedural-canvas"
                  phx-hook="HeerichProceduralDemo"
                  phx-update="ignore"
                  data-demo-kind="scale"
                >
                </div>
              </article>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp demo_focus_lookup(samples) do
    Enum.reduce(samples, %{}, fn sample, acc ->
      markers =
        case Map.get(sample.scene, "faces", []) do
          [face | _rest] -> Map.get(face, "markers", [])
          _ -> []
        end

      Enum.reduce(markers, acc, fn marker, marker_acc ->
        Map.put(marker_acc, marker["id"], %{
          sample_title: sample.title,
          eyebrow: sample.eyebrow,
          description: sample.description,
          note: sample.note,
          label: marker["label"] || sample.title,
          watch_for: watch_for(sample.id)
        })
      end)
    end)
  end

  defp default_demo_focus(samples, lookup) do
    with sample when not is_nil(sample) <- List.first(samples),
         target_id when is_binary(target_id) <- sample.selected_target_id,
         focus when is_map(focus) <- Map.get(lookup, target_id) do
      focus
    else
      _ ->
        fallback_demo_focus()
    end
  end

  defp demo_focus_for(lookup, target_id) do
    Map.get(lookup, target_id, fallback_demo_focus())
  end

  defp fallback_demo_focus do
    %{
      sample_title: "HoverCycle gallery",
      eyebrow: "Live guide",
      description:
        "Hover or select any shape in the gallery and this panel will explain what that sample is showing.",
      note: "The guide follows the last shape you touched.",
      label: "Waiting for focus",
      watch_for: "How the scene changes when one part of it wakes up."
    }
  end

  defp watch_for("default-primitive"),
    do: "The shared default loop on both the body and the sigil."

  defp watch_for("collapse-observatory"),
    do: "A quieter inward pull that feels measured instead of dramatic."

  defp watch_for("explode-cluster"),
    do: "Several linked pieces waking up together from one touch."

  defp watch_for("phase-operator"),
    do: "A sharper pass that slides and fades instead of collapsing."

  defp watch_for("marker-only"), do: "Only the sign moves while the body stays still."
  defp watch_for("polygons-only"), do: "The body shifts while the sign stays anchored."

  defp watch_for("scaled-voxels"),
    do: "The form narrows from a fixed anchor instead of changing its footprint."

  defp watch_for("carved-walls"), do: "Real negative space opening inside the mass."
  defp watch_for("restyled-geometry"), do: "Placed geometry changing tone without being rebuilt."
  defp watch_for(_sample_id), do: "What changes when the scene wakes up."
end
