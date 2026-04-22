defmodule PlatformPhxWeb.TechtreeLive do
  use PlatformPhxWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Techtree")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="techtree"
      header_eyebrow="Research lane"
      header_title="Techtree"
      theme_class="rg-regent-theme-platform"
    >
      <div id="platform-techtree-shell" class="px-4 py-4 sm:px-5 sm:py-5 xl:px-7 xl:py-6">
        <div class="space-y-4">
          <section
            id="platform-techtree-hero"
            class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_98%,var(--card)_2%),color-mix(in_oklch,var(--background)_94%,var(--card)_6%))] p-5 shadow-[0_32px_76px_-56px_color-mix(in_oklch,var(--brand-ink)_36%,transparent)] sm:p-7"
          >
            <div class="grid gap-6 xl:grid-cols-[minmax(0,0.88fr)_minmax(34rem,1.12fr)] xl:items-start">
              <div class="space-y-5">
                <div class="space-y-4">
                  <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--brand-ink)_78%,var(--foreground)_22%)]">
                    Research • Review • Publish
                  </p>
                  <h1 class="font-display text-[clamp(3.35rem,7vw,5.9rem)] leading-[0.84] tracking-[-0.065em] text-[color:var(--foreground)]">
                    Techtree
                  </h1>
                  <p class="max-w-[27rem] text-[1.02rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_72%,var(--muted-foreground)_28%)]">
                    Regents CLI starts the setup. Techtree is where research becomes readable,
                    reviewable, and publishable.
                  </p>
                </div>

                <div class="flex flex-wrap gap-3">
                  <a
                    href="https://techtree.sh"
                    target="_blank"
                    rel="noreferrer"
                    class="inline-flex h-12 items-center gap-2 rounded-[1rem] bg-[color:var(--brand-ink)] px-6 text-sm font-semibold text-white transition hover:translate-y-[-1px] hover:bg-[color:color-mix(in_oklch,var(--brand-ink)_88%,black_12%)]"
                  >
                    Open Techtree <span aria-hidden="true">→</span>
                  </a>
                  <.link
                    navigate={~p"/cli"}
                    class="inline-flex h-12 items-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-6 text-sm font-medium text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_30%,var(--border)_70%)] hover:text-[color:var(--brand-ink)]"
                  >
                    View CLI
                  </.link>
                </div>

                <div class="flex min-h-[4.6rem] items-center justify-between gap-3 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_97%,var(--card)_3%)] px-4 shadow-[inset_0_1px_0_color-mix(in_oklch,white_60%,transparent)]">
                  <div class="flex min-w-0 items-center gap-3">
                    <span class="text-[1.15rem] text-[color:color-mix(in_oklch,var(--foreground)_36%,var(--muted-foreground)_64%)]">
                      $
                    </span>
                    <code class="truncate font-mono text-[1.02rem] text-[color:var(--foreground)]">
                      regents techtree start
                    </code>
                  </div>
                  <button
                    type="button"
                    class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] text-[color:color-mix(in_oklch,var(--foreground)_72%,var(--muted-foreground)_28%)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_28%,var(--border)_72%)] hover:text-[color:var(--brand-ink)]"
                    aria-label="Copy regents techtree start"
                  >
                    <.icon name="hero-clipboard" class="h-4 w-4" />
                  </button>
                </div>
              </div>

              <section class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,transparent),color-mix(in_oklch,var(--card)_95%,transparent))] px-4 py-4 shadow-[inset_0_1px_0_color-mix(in_oklch,white_64%,transparent)] sm:px-6 sm:py-5">
                <div class="relative min-h-[19rem] overflow-hidden rounded-[1.4rem] border border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_94%,transparent),color-mix(in_oklch,var(--card)_88%,transparent))]">
                  <div
                    class="absolute inset-0 opacity-60"
                    style="background-image: linear-gradient(to right, color-mix(in oklch, var(--border) 48%, transparent) 1px, transparent 1px), linear-gradient(to bottom, color-mix(in oklch, var(--border) 42%, transparent) 1px, transparent 1px); background-size: 2.9rem 2.9rem;"
                  >
                  </div>
                  <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_left,color-mix(in_oklch,var(--brand-ink)_12%,transparent),transparent_30%),radial-gradient(circle_at_bottom_right,color-mix(in_oklch,#22c3c3_16%,transparent),transparent_26%)]">
                  </div>

                  <div class="absolute right-4 top-4 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] px-4 py-3 text-sm shadow-[0_18px_40px_-30px_color-mix(in_oklch,var(--foreground)_28%,transparent)]">
                    <%= for legend <- techtree_legends() do %>
                      <div class="flex items-center gap-2.5 not-first:mt-2">
                        <span class={["h-3 w-3 rounded-full", legend.dot]} />
                        <span class="text-[color:var(--foreground)]">{legend.label}</span>
                      </div>
                    <% end %>
                  </div>

                  <div class="absolute inset-0 hidden sm:block">
                    <%= for edge <- techtree_edges() do %>
                      <div
                        class="absolute h-px origin-left bg-[linear-gradient(90deg,color-mix(in_oklch,#56d5de_72%,transparent),color-mix(in_oklch,#8ec9ff_62%,transparent))]"
                        style={edge_style(edge)}
                      >
                      </div>
                    <% end %>
                  </div>

                  <%= for node <- techtree_nodes() do %>
                    <section
                      class={[
                        "absolute rounded-[1rem] border bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] px-4 py-3 shadow-[0_20px_36px_-28px_color-mix(in_oklch,var(--foreground)_26%,transparent)]",
                        node.featured &&
                          "border-[color:color-mix(in_oklch,#2563eb_32%,var(--border)_68%)] shadow-[0_26px_42px_-26px_color-mix(in_oklch,#2563eb_24%,transparent)]",
                        not node.featured &&
                          "border-[color:color-mix(in_oklch,var(--border)_88%,transparent)]"
                      ]}
                      style={node.position}
                    >
                      <div class="flex items-start gap-3">
                        <span class={["mt-1 h-3.5 w-3.5 rounded-full shrink-0", node.dot]} />
                        <div>
                          <p class="text-[0.96rem] font-semibold leading-none text-[color:var(--foreground)]">
                            {node.title}
                          </p>
                          <p class="mt-1 text-xs leading-5 text-[color:var(--muted-foreground)]">
                            {node.copy}
                          </p>
                        </div>
                      </div>
                    </section>
                  <% end %>
                </div>
              </section>
            </div>
          </section>

          <section
            id="platform-techtree-summary-grid"
            class="grid gap-4 xl:grid-cols-[minmax(0,1.02fr)_minmax(0,1.04fr)_minmax(0,0.98fr)_minmax(16.5rem,0.86fr)]"
          >
            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_22%,var(--border)_78%)] bg-[color:color-mix(in_oklch,#2563eb_9%,var(--background)_91%)] text-[color:var(--brand-ink)]">
                  <.icon name="hero-cursor-arrow-ripple" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Purpose
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    Techtree is the agent research surface. It turns scattered inputs into a
                    structured knowledge graph, then guides you through BBH-Train, capsule
                    building, review, and publishing.
                  </p>
                </div>
              </div>

              <div class="mt-8 flex flex-wrap gap-x-5 gap-y-3 text-sm text-[color:var(--foreground)]">
                <%= for point <- techtree_purpose_points() do %>
                  <div class="flex items-center gap-2">
                    <span class="inline-flex h-4 w-4 items-center justify-center rounded-full border border-[color:color-mix(in_oklch,#16a394_28%,var(--border)_72%)] text-[color:#149280]">
                      <.icon name="hero-check" class="h-2.5 w-2.5" />
                    </span>
                    <span>{point}</span>
                  </div>
                <% end %>
              </div>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_22%,var(--border)_78%)] bg-[color:color-mix(in_oklch,#2563eb_9%,var(--background)_91%)] text-[color:var(--brand-ink)]">
                  <.icon name="hero-square-3-stack-3d" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Tech stack
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    A curated stack built for traceable research and rigorous review.
                  </p>
                </div>
              </div>

              <div class="mt-6 flex flex-wrap gap-2.5">
                <%= for item <- techtree_stack_items() do %>
                  <a
                    href={item.href}
                    target="_blank"
                    rel="noreferrer"
                    class="rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:var(--background)] px-3 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_30%,var(--border)_70%)] hover:text-[color:var(--brand-ink)]"
                  >
                    {item.label}
                  </a>
                <% end %>
              </div>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_22%,var(--border)_78%)] bg-[color:color-mix(in_oklch,#2563eb_9%,var(--background)_91%)] text-[color:var(--brand-ink)]">
                  <.icon name="hero-sparkles" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Agent Skill
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    Techtree is the research and synthesis skill. It excels at decomposing
                    problems, finding evidence, running BBH-Train, and producing publishable
                    outputs with full citations.
                  </p>
                </div>
              </div>

              <div class="mt-6 rounded-[1rem] border border-[color:color-mix(in_oklch,#16a394_20%,var(--border)_80%)] bg-[color:color-mix(in_oklch,#16a394_8%,var(--background)_92%)] px-4 py-3 text-sm text-[color:#116f63] dark:text-[color:#9ad9cb]">
                <div class="flex items-center gap-3">
                  <span class="inline-flex h-6 w-6 items-center justify-center rounded-full border border-current/20">
                    <.icon name="hero-check" class="h-3.5 w-3.5" />
                  </span>
                  <span>Primary skill: Research • Synthesis • Publishing</span>
                </div>
              </div>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_22%,var(--border)_78%)] bg-[color:color-mix(in_oklch,#2563eb_9%,var(--background)_91%)] text-[color:var(--brand-ink)]">
                  <.icon name="hero-eye" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Preview
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    Open your live Techtree site to explore the graph, capsules, and published
                    work.
                  </p>
                </div>
              </div>

              <div class="mt-6 overflow-hidden rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_94%,transparent),color-mix(in_oklch,var(--card)_90%,transparent))]">
                <div class="grid grid-cols-[5rem_1fr]">
                  <div class="border-r border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_98%,transparent),color-mix(in_oklch,var(--card)_94%,transparent))] p-3">
                    <div class="space-y-2">
                      <div class="h-2 rounded-full bg-[color:color-mix(in_oklch,var(--border)_75%,transparent)]" />
                      <div class="h-2 rounded-full bg-[color:color-mix(in_oklch,var(--border)_60%,transparent)]" />
                      <div class="h-2 rounded-full bg-[color:color-mix(in_oklch,var(--border)_55%,transparent)]" />
                    </div>
                  </div>
                  <div class="relative min-h-[7rem] p-4">
                    <div
                      class="absolute inset-0 opacity-55"
                      style="background-image: linear-gradient(to right, color-mix(in oklch, var(--border) 44%, transparent) 1px, transparent 1px), linear-gradient(to bottom, color-mix(in oklch, var(--border) 44%, transparent) 1px, transparent 1px); background-size: 2.35rem 2.35rem;"
                    >
                    </div>
                    <%= for point <- techtree_preview_points() do %>
                      <span
                        class={["absolute h-2.5 w-2.5 rounded-full", point.dot]}
                        style={point.position}
                      />
                    <% end %>
                    <%= for edge <- techtree_preview_edges() do %>
                      <div
                        class="absolute h-px origin-left bg-[linear-gradient(90deg,color-mix(in_oklch,#60d4de_72%,transparent),color-mix(in_oklch,#77a8ff_66%,transparent))]"
                        style={edge_style(edge)}
                      >
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <a
                href="https://techtree.sh"
                target="_blank"
                rel="noreferrer"
                class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-[color:var(--brand-ink)] transition hover:gap-2.5"
              >
                Open Techtree site <span aria-hidden="true">→</span>
              </a>
            </article>
          </section>

          <section
            id="platform-techtree-cli-rails"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-4 py-5 shadow-[0_32px_76px_-56px_color-mix(in_oklch,var(--brand-ink)_32%,transparent)] sm:px-5"
          >
            <div class="flex flex-col gap-2 border-b border-[color:color-mix(in_oklch,var(--border)_82%,transparent)] pb-4 md:flex-row md:items-baseline md:gap-4">
              <h2 class="font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--brand-ink)]">
                CLI rails
              </h2>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Everything you need to run Techtree from the terminal.
              </p>
            </div>

            <div class="mt-5 grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
              <%= for card <- techtree_cli_cards() do %>
                <article class="rounded-[1.3rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_97%,var(--card)_3%)] p-4 shadow-[0_22px_50px_-42px_color-mix(in_oklch,var(--foreground)_24%,transparent)]">
                  <div class="flex items-start gap-4">
                    <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_18%,var(--border)_82%)] bg-[color:color-mix(in_oklch,#2563eb_7%,var(--background)_93%)] text-[color:var(--brand-ink)]">
                      <.icon name={card.icon} class="h-5 w-5" />
                    </div>
                    <div class="min-w-0">
                      <h3 class="font-display text-[1.18rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        {card.title}
                      </h3>
                      <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        {card.copy}
                      </p>
                    </div>
                  </div>

                  <div class="mt-5 flex min-h-[3.4rem] items-center justify-between gap-3 rounded-[0.9rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:var(--background)] px-3.5">
                    <code class="truncate font-mono text-[0.92rem] text-[color:var(--foreground)]">
                      {card.command}
                    </code>
                    <button
                      type="button"
                      class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-[0.7rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] text-[color:color-mix(in_oklch,var(--foreground)_70%,var(--muted-foreground)_30%)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_24%,var(--border)_76%)] hover:text-[color:var(--brand-ink)]"
                      aria-label={"Copy #{card.command}"}
                    >
                      <.icon name="hero-clipboard" class="h-4 w-4" />
                    </button>
                  </div>

                  <a
                    href={card.href}
                    target="_blank"
                    rel="noreferrer"
                    class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-[color:var(--brand-ink)] transition hover:gap-2.5"
                  >
                    Learn more <span aria-hidden="true">→</span>
                  </a>
                </article>
              <% end %>
            </div>
          </section>

          <section class="rounded-[1.4rem] border border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,#e8f2ff_72%,var(--background)_28%),color-mix(in_oklch,var(--background)_88%,var(--card)_12%))] px-4 py-4 shadow-[0_26px_56px_-48px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)] sm:px-5">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] bg-[linear-gradient(180deg,color-mix(in_oklch,#6faeff_86%,white_14%),color-mix(in_oklch,#3d7df5_82%,black_18%))] text-white shadow-[0_18px_36px_-22px_rgba(37,99,235,0.45)]">
                  <.icon name="hero-command-line" class="h-6 w-6" />
                </div>
                <div>
                  <p class="font-medium text-[color:var(--foreground)]">
                    The Regents CLI is your operator console. Techtree is the research surface.
                    Together they form the full workflow: setup → research → review → publish.
                  </p>
                </div>
              </div>

              <.link
                navigate={~p"/cli"}
                class="inline-flex h-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] px-5 text-sm font-medium text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_28%,var(--border)_72%)] hover:text-[color:var(--brand-ink)]"
              >
                View CLI docs
              </.link>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp techtree_legends do
    [
      %{label: "Research", dot: "bg-[#35b7b1]"},
      %{label: "Synthesis", dot: "bg-[#3a86ff]"},
      %{label: "Output", dot: "bg-[#173f8f]"}
    ]
  end

  defp techtree_nodes do
    [
      %{
        title: "Market Need",
        copy: "Source",
        position: "left: 4.5rem; top: 2.2rem; width: 10.3rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Hypothesis",
        copy: "Derived",
        position: "left: 16.7rem; top: 2.2rem; width: 9.4rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Capsules",
        copy: "Evidence",
        position: "right: 12.7rem; top: 2rem; width: 9rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Literature",
        copy: "Sources",
        position: "left: 2rem; top: 7.9rem; width: 8.7rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Thesis",
        copy: "Core",
        position: "left: 14.2rem; top: 8rem; width: 6.6rem;",
        dot: "bg-[#3a86ff]",
        featured: true
      },
      %{
        title: "Architecture",
        copy: "Design",
        position: "left: 26rem; top: 7.6rem; width: 10.2rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Regulatory",
        copy: "Constraints",
        position: "left: 5rem; bottom: 2.6rem; width: 9.8rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Experiments",
        copy: "Results",
        position: "left: 20.7rem; bottom: 1.6rem; width: 8.5rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Review",
        copy: "Internal",
        position: "right: 10.6rem; bottom: 4.2rem; width: 7.4rem;",
        dot: "bg-[#35b7b1]",
        featured: false
      },
      %{
        title: "Publish",
        copy: "Output",
        position: "right: 2rem; bottom: 3.6rem; width: 7rem;",
        dot: "bg-[#173f8f]",
        featured: false
      }
    ]
  end

  defp techtree_edges do
    [
      %{position: "left: 9.8rem; top: 4.4rem;", width: 11.2, rotate: 18},
      %{position: "left: 19.1rem; top: 4.3rem;", width: 8.1, rotate: 118},
      %{position: "left: 20.3rem; top: 9.9rem;", width: 6.9, rotate: -7},
      %{position: "left: 16.2rem; top: 10.4rem;", width: 9.7, rotate: -129},
      %{position: "left: 18.8rem; top: 10rem;", width: 9.4, rotate: 59},
      %{position: "left: 19rem; top: 10rem;", width: 11.6, rotate: -52},
      %{position: "left: 29.4rem; top: 9.8rem;", width: 8.8, rotate: 30},
      %{position: "left: 31rem; top: 10rem;", width: 8.4, rotate: 115},
      %{position: "left: 33.2rem; top: 10.3rem;", width: 8.8, rotate: 29}
    ]
  end

  defp techtree_stack_items do
    [
      %{label: "PostgreSQL", href: "https://www.postgresql.org"},
      %{label: "Ecto", href: "https://hexdocs.pm/ecto/Ecto.html"},
      %{label: "Phoenix LiveView", href: "https://hexdocs.pm/phoenix_live_view/welcome.html"},
      %{label: "Elixir", href: "https://elixir-lang.org"},
      %{label: "Vector search", href: "https://github.com/pgvector/pgvector"},
      %{label: "Graph store", href: "https://neo4j.com"},
      %{label: "Oban", href: "https://hexdocs.pm/oban/Oban.html"},
      %{label: "PubSub", href: "https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html"},
      %{label: "Rich content", href: "https://developer.mozilla.org/en-US/docs/Web/HTML"},
      %{label: "Object storage", href: "https://aws.amazon.com/s3/"},
      %{label: "Telemetry", href: "https://hexdocs.pm/telemetry/readme.html"}
    ]
  end

  defp techtree_purpose_points do
    ["Structured research", "Transparent lineage", "Publish-ready"]
  end

  defp techtree_preview_points do
    [
      %{position: "left: 2.7rem; top: 3.2rem;", dot: "bg-[#3a86ff]"},
      %{position: "left: 7rem; top: 2rem;", dot: "bg-[#35b7b1]"},
      %{position: "left: 11.4rem; top: 4.4rem;", dot: "bg-[#3a86ff]"},
      %{position: "left: 15.8rem; top: 2.7rem;", dot: "bg-[#3a86ff]"},
      %{position: "left: 20rem; top: 4.7rem;", dot: "bg-[#173f8f]"}
    ]
  end

  defp techtree_preview_edges do
    [
      %{position: "left: 3.2rem; top: 3.5rem;", width: 4.4, rotate: -18},
      %{position: "left: 7.5rem; top: 2.4rem;", width: 4.8, rotate: 28},
      %{position: "left: 11.8rem; top: 4.7rem;", width: 4.7, rotate: -21},
      %{position: "left: 16.2rem; top: 3rem;", width: 4.5, rotate: 26}
    ]
  end

  defp techtree_cli_cards do
    [
      %{
        icon: "hero-sparkles",
        title: "Start Techtree",
        copy: "Initialize the research workspace and local services.",
        command: "regents techtree start",
        href: "https://github.com/regents-ai/techtree"
      },
      %{
        icon: "hero-academic-cap",
        title: "BBH-Train",
        copy: "Run structured research and synthesis on a topic.",
        command: "regents techtree train",
        href: "https://github.com/regents-ai/techtree"
      },
      %{
        icon: "hero-cube-transparent",
        title: "Capsules",
        copy: "Build and manage evidence capsules.",
        command: "regents techtree capsule",
        href: "https://github.com/regents-ai/techtree"
      },
      %{
        icon: "hero-shield-check",
        title: "Review",
        copy: "Open the review queue and resolve items.",
        command: "regents techtree review",
        href: "https://github.com/regents-ai/techtree"
      },
      %{
        icon: "hero-arrow-up-tray",
        title: "Publish",
        copy: "Publish approved work to the public site.",
        command: "regents techtree publish",
        href: "https://github.com/regents-ai/techtree"
      },
      %{
        icon: "hero-share",
        title: "Graph",
        copy: "Explore the knowledge graph in your terminal.",
        command: "regents techtree graph",
        href: "https://techtree.sh"
      }
    ]
  end

  defp edge_style(edge) do
    "transform: rotate(#{edge.rotate}deg); width: #{edge.width}rem; #{edge.position}"
  end
end
