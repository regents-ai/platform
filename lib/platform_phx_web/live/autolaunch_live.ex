defmodule PlatformPhxWeb.AutolaunchLive do
  use PlatformPhxWeb, :live_view

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Autolaunch")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="autolaunch"
      header_eyebrow="Capital lane"
      header_title="Autolaunch"
      theme_class="rg-regent-theme-platform"
    >
      <div id="platform-autolaunch-shell" class="px-4 py-4 sm:px-5 sm:py-5 xl:px-7 xl:py-6">
        <div class="space-y-4">
          <section
            id="platform-autolaunch-hero"
            class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_98%,var(--card)_2%),color-mix(in_oklch,var(--background)_94%,var(--card)_6%))] p-5 shadow-[0_32px_76px_-56px_color-mix(in_oklch,var(--brand-ink)_38%,transparent)] sm:p-7"
          >
            <div class="grid gap-5 2xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.3fr)_minmax(18rem,0.9fr)] 2xl:items-start">
              <div class="space-y-5">
                <div class="space-y-4">
                  <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--brand-ink)_78%,var(--foreground)_22%)]">
                    Capital formation for agents
                  </p>
                  <h1 class="font-display text-[clamp(3.35rem,7vw,5.9rem)] leading-[0.84] tracking-[-0.065em] text-[color:var(--foreground)]">
                    Autolaunch
                  </h1>
                  <p class="max-w-[29rem] text-[1.02rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_72%,var(--muted-foreground)_28%)]">
                    Turn agent edge into runway. Autolaunch gives operators a compliant path to
                    raise capital for agents, with built-in rails for planning, backers, treasury,
                    and ongoing revenue.
                  </p>
                </div>

                <div class="flex flex-wrap gap-3">
                  <a
                    href="https://autolaunch.sh"
                    target="_blank"
                    rel="noreferrer"
                    class="inline-flex h-12 items-center gap-2 rounded-[1rem] bg-[color:var(--brand-ink)] px-6 text-sm font-semibold text-white transition hover:translate-y-[-1px] hover:bg-[color:color-mix(in_oklch,var(--brand-ink)_88%,black_12%)]"
                  >
                    Open Autolaunch <span aria-hidden="true">→</span>
                  </a>
                  <.link
                    navigate={~p"/cli"}
                    class="inline-flex h-12 items-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-6 text-sm font-medium text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_30%,var(--border)_70%)] hover:text-[color:var(--brand-ink)]"
                  >
                    View CLI
                  </.link>
                </div>

                <div class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm text-[color:var(--foreground)] xl:grid-cols-4">
                  <%= for item <- autolaunch_hero_points() do %>
                    <div class="flex items-center gap-2.5">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] text-[color:var(--brand-ink)]">
                        <.icon name={item.icon} class="h-4.5 w-4.5" />
                      </span>
                      <span>{item.label}</span>
                    </div>
                  <% end %>
                </div>
              </div>

              <section class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,transparent),color-mix(in_oklch,var(--card)_95%,transparent))] px-5 py-4 shadow-[inset_0_1px_0_color-mix(in_oklch,white_64%,transparent)]">
                <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--foreground)_58%,var(--muted-foreground)_42%)]">
                  The launch pipeline
                </p>

                <div class="mt-6 grid gap-4 md:grid-cols-5">
                  <%= for step <- autolaunch_pipeline_steps() do %>
                    <div class="relative">
                      <%= if step.connector? do %>
                        <div class="absolute left-[calc(50%+1.75rem)] right-[-1.2rem] top-8 hidden h-px bg-[linear-gradient(90deg,color-mix(in_oklch,#4378ff_72%,transparent),color-mix(in_oklch,#37d6b2_74%,transparent))] md:block">
                        </div>
                      <% end %>

                      <section>
                        <div class={[
                          "mx-auto flex h-16 w-16 items-center justify-center rounded-full border bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] shadow-[0_18px_38px_-28px_color-mix(in_oklch,var(--foreground)_22%,transparent)]",
                          step.active? &&
                            "border-[color:color-mix(in_oklch,#29c6ae_55%,var(--border)_45%)] text-[color:#16a394]",
                          not step.active? &&
                            "border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] text-[color:var(--brand-ink)]"
                        ]}>
                          <.icon name={step.icon} class="h-6 w-6" />
                        </div>
                        <h2 class="mt-5 text-center font-display text-[1.25rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                          {step.title}
                        </h2>
                        <p class="mt-3 text-center text-sm leading-7 text-[color:var(--muted-foreground)]">
                          {step.copy}
                        </p>
                      </section>
                    </div>
                  <% end %>
                </div>

                <div class="mt-7 rounded-[1rem] border border-[color:color-mix(in_oklch,#37cbb7_20%,var(--border)_80%)] bg-[color:color-mix(in_oklch,#37cbb7_8%,var(--background)_92%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <span class="inline-flex h-10 w-10 items-center justify-center rounded-[0.95rem] bg-[color:color-mix(in_oklch,#37cbb7_14%,var(--background)_86%)] text-[color:#16a394]">
                      <.icon name="hero-sparkles" class="h-5 w-5" />
                    </span>
                    <div>
                      <p class="font-medium text-[color:var(--foreground)]">
                        Built for agents, not tokens.
                      </p>
                      <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Autolaunch connects capital, execution, and revenue in one continuous
                        system.
                      </p>
                    </div>
                  </div>
                </div>
              </section>

              <div class="space-y-4">
                <section class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-4 shadow-[0_28px_60px_-50px_color-mix(in_oklch,var(--foreground)_22%,transparent)]">
                  <div class="flex items-center justify-between gap-3">
                    <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--foreground)_58%,var(--muted-foreground)_42%)]">
                      Preview example
                    </p>
                    <div class="flex items-center gap-2 text-sm text-[color:var(--foreground)]">
                      <span class="h-2.5 w-2.5 rounded-full bg-[#22c55e]" />
                      <span>Example board</span>
                    </div>
                  </div>

                  <div class="mt-4 overflow-hidden rounded-[1.1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_92%,black_8%)] text-white">
                    <div class="grid grid-cols-[6rem_1fr] gap-3 p-4">
                      <div class="flex h-[5.7rem] w-[5.7rem] items-center justify-center rounded-[1rem] border border-white/70">
                        <img
                          src={~p"/images/regents-logo.png"}
                          alt=""
                          class="h-9 w-9 rounded-lg object-cover"
                        />
                      </div>
                      <div>
                        <h2 class="font-display text-[1.4rem] leading-none tracking-[-0.04em]">
                          Sentinel Research Agent
                        </h2>
                        <p class="mt-3 text-sm leading-6 text-white/80">
                          Research • Risk • Monitoring
                        </p>
                        <p class="mt-3 text-sm leading-6 text-white/82">
                          Autonomous research agent focused on risk signals and market
                          intelligence.
                        </p>
                      </div>
                    </div>
                  </div>

                  <div class="overflow-hidden rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)]">
                    <div class="grid grid-cols-3 border-b border-[color:color-mix(in_oklch,var(--border)_82%,transparent)]">
                      <%= for item <- autolaunch_preview_metrics() do %>
                        <div class="px-4 py-3">
                          <p class="text-[0.7rem] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                            {item.label}
                          </p>
                          <p class="mt-2 font-display text-[1.18rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                            {item.value}
                          </p>
                        </div>
                      <% end %>
                    </div>

                    <div class="px-4 py-3">
                      <div class="flex items-center justify-between gap-3 text-sm text-[color:var(--foreground)]">
                        <span>Committed</span>
                        <span>64.9%</span>
                      </div>
                      <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-[color:color-mix(in_oklch,var(--border)_72%,transparent)]">
                        <div class="h-full w-[64.9%] rounded-full bg-[linear-gradient(90deg,color-mix(in_oklch,#2563eb_82%,white_18%),color-mix(in_oklch,#1f5fd8_74%,#2bc7af_26%))]" />
                      </div>
                      <div class="mt-4 grid grid-cols-2 gap-4 border-t border-[color:color-mix(in_oklch,var(--border)_82%,transparent)] pt-4">
                        <%= for item <- autolaunch_preview_footer_metrics() do %>
                          <div>
                            <p class="text-[0.7rem] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                              {item.label}
                            </p>
                            <p class="mt-2 font-display text-[1.18rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                              {item.value}
                            </p>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <a
                    href="https://autolaunch.sh"
                    target="_blank"
                    rel="noreferrer"
                    class="mt-4 flex h-11 items-center justify-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] text-sm font-medium text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_28%,var(--border)_72%)] hover:text-[color:var(--brand-ink)]"
                  >
                    View preview <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                  </a>
                </section>
              </div>
            </div>
          </section>

          <section
            id="platform-autolaunch-summary-grid"
            class="grid gap-4 2xl:grid-cols-[minmax(0,1.02fr)_minmax(0,0.92fr)_minmax(0,0.96fr)_minmax(18rem,0.92fr)]"
          >
            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] bg-[linear-gradient(180deg,color-mix(in_oklch,#2563eb_86%,white_14%),color-mix(in_oklch,#214fd4_82%,black_18%))] text-white shadow-[0_18px_38px_-24px_rgba(37,99,235,0.4)]">
                  <.icon name="hero-cursor-arrow-ripple" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Purpose
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    Autolaunch turns agent performance and market need into fundable opportunities.
                  </p>
                </div>
              </div>

              <ul class="mt-7 space-y-4 text-sm leading-7 text-[color:var(--muted-foreground)]">
                <%= for point <- autolaunch_purpose_points() do %>
                  <li class="flex items-start gap-3">
                    <span class="mt-1 inline-flex h-5 w-5 items-center justify-center rounded-full text-[color:#2563eb]">
                      <.icon name="hero-check" class="h-4 w-4" />
                    </span>
                    <span>{point}</span>
                  </li>
                <% end %>
              </ul>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] bg-[linear-gradient(180deg,color-mix(in_oklch,#5878ff_84%,white_16%),color-mix(in_oklch,#4057d4_80%,black_20%))] text-white shadow-[0_18px_38px_-24px_rgba(64,87,212,0.35)]">
                  <.icon name="hero-square-3-stack-3d" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Operating rails
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    A modern stack that connects capital, execution, and accounting.
                  </p>
                </div>
              </div>

              <div class="mt-6 space-y-4">
                <%= for item <- autolaunch_stack_items() do %>
                  <div class="flex items-start gap-3">
                    <span class="inline-flex h-8 w-8 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] text-[color:var(--brand-ink)]">
                      <.icon name={item.icon} class="h-4 w-4" />
                    </span>
                    <div>
                      <p class="font-medium text-[color:var(--foreground)]">{item.title}</p>
                      <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                        {item.copy}
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] bg-[linear-gradient(180deg,color-mix(in_oklch,#2ec8b2_86%,white_14%),color-mix(in_oklch,#19a89a_82%,black_18%))] text-white shadow-[0_18px_38px_-24px_rgba(33,168,154,0.35)]">
                  <.icon name="hero-sparkles" class="h-6 w-6" />
                </div>
                <div>
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Agent Skill
                  </h2>
                  <p class="mt-4 text-[0.99rem] leading-8 text-[color:var(--muted-foreground)]">
                    Autolaunch evaluates the agent's capability and execution edge.
                  </p>
                </div>
              </div>

              <ul class="mt-7 space-y-4 text-sm leading-7 text-[color:var(--muted-foreground)]">
                <%= for point <- autolaunch_skill_points() do %>
                  <li class="flex items-start gap-3">
                    <span class="mt-1 inline-flex h-5 w-5 items-center justify-center rounded-full text-[color:#16a394]">
                      <.icon name="hero-check" class="h-4 w-4" />
                    </span>
                    <span>{point}</span>
                  </li>
                <% end %>
              </ul>
            </article>

            <article class="rounded-[1.65rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5 shadow-[0_30px_70px_-58px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--foreground)_58%,var(--muted-foreground)_42%)]">
                    Autolaunch preview
                  </p>
                </div>
              </div>

              <div class="mt-6 grid gap-4 border-b border-[color:color-mix(in_oklch,var(--border)_82%,transparent)] pb-5 sm:grid-cols-2">
                <div>
                  <p class="text-sm text-[color:var(--muted-foreground)]">Current source</p>
                  <p class="mt-2 font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                    Autolaunch
                  </p>
                  <p class="mt-1 text-sm text-[color:#16a394]">Open the launch app for live data</p>
                </div>
                <div>
                  <p class="text-sm text-[color:var(--muted-foreground)]">Owner</p>
                  <p class="mt-2 font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                    autolaunch.sh
                  </p>
                </div>
              </div>

              <div class="mt-5 flex items-center justify-between gap-3">
                <p class="text-sm font-medium text-[color:var(--foreground)]">Example rows</p>
                <a
                  href="https://autolaunch.sh"
                  target="_blank"
                  rel="noreferrer"
                  class="text-sm font-medium text-[color:var(--brand-ink)]"
                >
                  View all
                </a>
              </div>

              <div class="mt-3 space-y-2.5">
                <%= for item <- market_activity_rows() do %>
                  <div class="grid grid-cols-[1.8rem_minmax(0,1fr)_auto_auto] items-center gap-3 rounded-[0.9rem] py-1.5">
                    <div class="flex h-7 w-7 items-center justify-center rounded-full bg-[color:color-mix(in_oklch,var(--brand-ink)_92%,black_8%)]">
                      <img
                        src={~p"/images/regents-logo.png"}
                        alt=""
                        class="h-4 w-4 rounded object-cover"
                      />
                    </div>
                    <p class="truncate text-sm text-[color:var(--foreground)]">{item.name}</p>
                    <p class="text-xs text-[color:var(--muted-foreground)]">{item.amount}</p>
                    <span class={[
                      "inline-flex min-w-[4.75rem] justify-center rounded-full px-2.5 py-1 text-xs font-medium",
                      item.status_class
                    ]}>
                      {item.status}
                    </span>
                  </div>
                <% end %>
              </div>
            </article>
          </section>

          <section
            id="platform-autolaunch-cli-rails"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-4 py-5 shadow-[0_32px_76px_-56px_color-mix(in_oklch,var(--brand-ink)_32%,transparent)] sm:px-5"
          >
            <p class="text-[0.72rem] font-semibold uppercase tracking-[0.34em] text-[color:color-mix(in_oklch,var(--brand-ink)_78%,var(--foreground)_22%)]">
              CLI rails
            </p>

            <div class="mt-4 grid gap-4 xl:grid-cols-3">
              <%= for card <- autolaunch_cli_cards() do %>
                <article class="rounded-[1.3rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_97%,var(--card)_3%)] p-4 shadow-[0_22px_50px_-42px_color-mix(in_oklch,var(--foreground)_24%,transparent)]">
                  <div class="flex items-start gap-4">
                    <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,#2563eb_18%,var(--border)_82%)] bg-[color:color-mix(in_oklch,#2563eb_7%,var(--background)_93%)] text-[color:var(--brand-ink)]">
                      <.icon name={card.icon} class="h-5 w-5" />
                    </div>
                    <div>
                      <h2 class="font-display text-[1.18rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        {card.title}
                      </h2>
                      <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        {card.copy}
                      </p>
                    </div>
                  </div>

                  <div class="mt-5 flex min-h-[3.6rem] items-center justify-between gap-3 rounded-[0.9rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:var(--background)] px-3.5">
                    <code class="truncate font-mono text-[0.88rem] text-[color:var(--foreground)]">
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
                    href="https://github.com/regents-ai/autolaunch"
                    target="_blank"
                    rel="noreferrer"
                    class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-[color:var(--brand-ink)] transition hover:gap-2.5"
                  >
                    View docs <span aria-hidden="true">→</span>
                  </a>
                </article>
              <% end %>
            </div>
          </section>

          <section class="rounded-[1.4rem] border border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,#e8f2ff_72%,var(--background)_28%),color-mix(in_oklch,var(--background)_88%,var(--card)_12%))] px-4 py-4 shadow-[0_26px_56px_-48px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)] sm:px-5">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div class="flex items-start gap-4">
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-[1rem] bg-[linear-gradient(180deg,color-mix(in_oklch,#2cc7b1_82%,white_18%),color-mix(in_oklch,#1ea79f_82%,black_18%))] text-white shadow-[0_18px_36px_-22px_rgba(33,168,154,0.42)]">
                  <.icon name="hero-rocket-launch" class="h-6 w-6" />
                </div>
                <div>
                  <p class="font-medium text-[color:var(--foreground)]">
                    Autolaunch is your path from agent to capital.
                  </p>
                  <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                    Plan, preview, launch, and operate with confidence.
                  </p>
                </div>
              </div>

              <div class="flex flex-wrap gap-3">
                <.link
                  navigate={~p"/app"}
                  class="inline-flex h-11 items-center justify-center rounded-[0.95rem] bg-[color:var(--brand-ink)] px-5 text-sm font-semibold text-white transition hover:translate-y-[-1px] hover:bg-[color:color-mix(in_oklch,var(--brand-ink)_88%,black_12%)]"
                >
                  Go to App setup
                </.link>
                <.link
                  navigate={~p"/cli"}
                  class="inline-flex h-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] px-5 text-sm font-medium text-[color:var(--foreground)] transition hover:border-[color:color-mix(in_oklch,var(--brand-ink)_28%,var(--border)_72%)] hover:text-[color:var(--brand-ink)]"
                >
                  View CLI
                </.link>
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp autolaunch_hero_points do
    [
      %{icon: "hero-shield-check", label: "Regulated rails"},
      %{icon: "hero-building-library", label: "On-chain treasury"},
      %{icon: "hero-user-group", label: "Transparent to backers"},
      %{icon: "hero-chart-bar-square", label: "Revenue aligned"}
    ]
  end

  defp autolaunch_pipeline_steps do
    [
      %{
        icon: "hero-flag",
        title: "Plan",
        copy: "Define the agent, raise target, token design, and terms.",
        connector?: true,
        active?: false
      },
      %{
        icon: "hero-eye",
        title: "Preview",
        copy: "Share a live preview for early backers.",
        connector?: true,
        active?: false
      },
      %{
        icon: "hero-user-group",
        title: "Commit",
        copy: "Backers commit funds during the raise window.",
        connector?: true,
        active?: false
      },
      %{
        icon: "hero-rocket-launch",
        title: "Launch",
        copy: "Funds lock in. Agent goes live. Market opens.",
        connector?: true,
        active?: true
      },
      %{
        icon: "hero-chart-bar",
        title: "Operate",
        copy: "Agent operates. Revenue flows to treasury.",
        connector?: false,
        active?: false
      }
    ]
  end

  defp autolaunch_preview_metrics do
    [
      %{label: "Target raise", value: "$250,000"},
      %{label: "Token", value: "SRNT"},
      %{label: "Valuation cap", value: "$2.5M"}
    ]
  end

  defp autolaunch_preview_footer_metrics do
    [
      %{label: "Backers", value: "127"},
      %{label: "Days left", value: "5"}
    ]
  end

  defp autolaunch_purpose_points do
    [
      "Plan raises with clear terms and caps",
      "Invite early backers with live previews",
      "Launch on-chain with transparent rails",
      "Operate, report, and grow revenue"
    ]
  end

  defp autolaunch_stack_items do
    [
      %{
        icon: "hero-command-line",
        title: "Launch app",
        copy: "Live launch experience"
      },
      %{
        icon: "hero-circle-stack",
        title: "Auction records",
        copy: "Launch workflow and market state"
      },
      %{
        icon: "hero-cube",
        title: "Treasury rails",
        copy: "Transparent fund custody and flows"
      },
      %{
        icon: "hero-arrow-path",
        title: "Activity timeline",
        copy: "Status, performance, and history"
      }
    ]
  end

  defp autolaunch_skill_points do
    [
      "Problem clarity and market need",
      "Strategy quality and data advantage",
      "Execution track record and reliability",
      "Revenue model and unit economics"
    ]
  end

  defp autolaunch_cli_cards do
    [
      %{
        icon: "hero-rectangle-group",
        title: "Plan a launch",
        copy: "Create the blueprint for your agent raise.",
        command: ~s(regents autolaunch plan --name "Sentinel" --target 250000 --token SRNT)
      },
      %{
        icon: "hero-command-line",
        title: "Publish preview",
        copy: "Share your launch preview with early backers.",
        command: "regents autolaunch preview publish --id srnt"
      },
      %{
        icon: "hero-rocket-launch",
        title: "Run the launch",
        copy: "Start the raise window and open commitments.",
        command: "regents autolaunch launch --id srnt"
      }
    ]
  end

  defp market_activity_rows do
    [
      %{
        name: "Sentinel Research Agent",
        amount: "$162K / $250K",
        status: "Live",
        status_class:
          "bg-[color:color-mix(in_oklch,#22c55e_16%,var(--background)_84%)] text-[#198754] dark:text-[#9ad9cb]"
      },
      %{
        name: "Edge Risk Monitor",
        amount: "$98K / $160K",
        status: "Live",
        status_class:
          "bg-[color:color-mix(in_oklch,#22c55e_16%,var(--background)_84%)] text-[#198754] dark:text-[#9ad9cb]"
      },
      %{
        name: "Yield Scout Agent",
        amount: "$74K / $120K",
        status: "Preview",
        status_class:
          "bg-[color:color-mix(in_oklch,#3b82f6_16%,var(--background)_84%)] text-[#2563eb] dark:text-[#93c5fd]"
      },
      %{
        name: "DataPilot Analyst",
        amount: "$53K / $100K",
        status: "Closed",
        status_class:
          "bg-[color:color-mix(in_oklch,var(--border)_82%,var(--background)_18%)] text-[color:var(--muted-foreground)]"
      }
    ]
  end
end
