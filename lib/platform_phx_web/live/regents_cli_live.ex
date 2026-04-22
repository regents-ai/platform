defmodule PlatformPhxWeb.RegentCliLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.RegentCliCatalog
  alias PlatformPhxWeb.PublicPageCatalog

  @impl true
  def mount(_params, _session, socket) do
    intro = RegentCliCatalog.intro()
    hero_highlights = RegentCliCatalog.hero_highlights()
    hero_quick_start_steps = RegentCliCatalog.hero_quick_start_steps()
    quick_start_note = RegentCliCatalog.quick_start_note()
    techtree_start_intro = RegentCliCatalog.techtree_start_intro()
    best_first_marks = RegentCliCatalog.best_first_marks()
    work_loop = RegentCliCatalog.work_loop()
    common_rule_cards = RegentCliCatalog.common_rule_cards()
    command_tiles = RegentCliCatalog.command_tiles()
    guidance_cards = RegentCliCatalog.guidance_cards()

    {:ok,
     socket
     |> assign(:page_title, "Regents CLI")
     |> assign(:intro, intro)
     |> assign(:hero_highlights, hero_highlights)
     |> assign(:hero_quick_start_steps, hero_quick_start_steps)
     |> assign(:quick_start_note, quick_start_note)
     |> assign(:techtree_start_intro, techtree_start_intro)
     |> assign(:best_first_marks, best_first_marks)
     |> assign(:work_loop, work_loop)
     |> assign(:common_rule_cards, common_rule_cards)
     |> assign(:command_tiles, command_tiles)
     |> assign(:guidance_cards, guidance_cards)
     |> assign(
       :page_markdown,
       PublicPageCatalog.cli_markdown()
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
      active_nav="cli"
      header_eyebrow="CLI"
      header_title="Regents CLI"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-regents-cli-shell"
        class="rg-regent-theme-platform space-y-6"
        phx-hook="BridgeReveal"
      >
        <section
          id="platform-regents-cli-hero"
          data-bridge-block
          class="overflow-hidden rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)]"
        >
          <div class="grid gap-0 xl:grid-cols-[minmax(0,1.03fr)_minmax(24rem,0.97fr)]">
            <div class="space-y-8 px-6 py-7 sm:px-8 sm:py-9">
              <div class="space-y-5">
                <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
                  Command the stack
                </p>
                <div class="space-y-4">
                  <h2 class="font-display text-[clamp(3.2rem,7vw,5.9rem)] leading-[0.88] tracking-[-0.075em] text-[color:var(--foreground)]">
                    Regents CLI
                  </h2>
                  <div class="max-w-[38rem] space-y-2 text-[1.18rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_76%,var(--muted-foreground)_24%)]">
                    <%= for paragraph <- @intro do %>
                      <p>{paragraph}</p>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="grid gap-4 md:grid-cols-3">
                <%= for highlight <- @hero_highlights do %>
                  <section class="rounded-[1.4rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 py-4">
                    <div class="flex items-start gap-3">
                      <div class="flex size-11 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                        <.icon name={highlight.icon} class="size-5" />
                      </div>
                      <div class="space-y-1">
                        <p class="text-sm font-medium text-[color:var(--foreground)]">
                          {highlight.title}
                        </p>
                        <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                          {highlight.body}
                        </p>
                      </div>
                    </div>
                  </section>
                <% end %>
              </div>
            </div>

            <section
              id="platform-regents-cli-quick-start"
              class="relative border-t border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-7 sm:px-8 sm:py-9 xl:border-l xl:border-t-0"
            >
              <div class="grid gap-8 xl:grid-cols-[minmax(0,1fr)_14rem]">
                <div class="space-y-5">
                  <div class="flex items-start justify-between gap-4">
                    <div class="space-y-2">
                      <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:color-mix(in_oklch,var(--foreground)_54%,var(--muted-foreground)_46%)]">
                        Try it locally
                      </p>
                      <h3 class="font-display text-[2.15rem] leading-none tracking-[-0.06em] text-[color:var(--foreground)]">
                        Quick start
                      </h3>
                    </div>

                    <button
                      id="platform-regents-cli-markdown-copy"
                      type="button"
                      phx-hook="ClipboardCopy"
                      class="inline-flex h-10 items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                      aria-label="Copy Regents CLI page as markdown"
                      title="Copy Regents CLI page as markdown"
                      data-copy-text={@page_markdown}
                    >
                      <span>Copy page as markdown</span>
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  </div>

                  <ol class="space-y-3">
                    <%= for {step, index} <- Enum.with_index(@hero_quick_start_steps, 1) do %>
                      <li class="grid grid-cols-[1.6rem_minmax(0,1fr)] gap-3">
                        <div class="mt-2 flex h-6 w-6 items-center justify-center rounded-full bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] text-[0.72rem] font-medium text-[color:var(--brand-ink)]">
                          {index}
                        </div>
                        <div class="space-y-2">
                          <p class="text-sm text-[color:var(--foreground)]">{step.title}</p>
                          <div class="flex items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-3">
                            <code class="min-w-0 flex-1 truncate text-[0.98rem] text-[color:var(--foreground)]">
                              {step.command}
                            </code>
                            <button
                              id={"platform-regents-cli-quick-start-copy-#{index}"}
                              type="button"
                              phx-hook="ClipboardCopy"
                              class="inline-flex h-8 w-8 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                              aria-label={"Copy quick start command #{index}"}
                              title={"Copy quick start command #{index}"}
                              data-copy-text={step.command}
                            >
                              <.icon name="hero-document-duplicate" class="size-4" />
                            </button>
                          </div>
                        </div>
                      </li>
                    <% end %>
                  </ol>

                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    {@quick_start_note}
                  </p>
                </div>

                <div class="relative hidden items-center justify-center xl:flex" aria-hidden="true">
                  <div class="absolute inset-auto h-44 w-44 rounded-[2.4rem] border border-dashed border-[color:color-mix(in_oklch,var(--brand-ink)_20%,transparent)] [transform:rotate(45deg)]">
                  </div>
                  <div class="absolute h-28 w-28 rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,var(--card)_4%),color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%))] shadow-[0_30px_60px_-38px_color-mix(in_oklch,var(--foreground)_22%,transparent)] [transform:rotate(45deg)]">
                  </div>
                  <div class="relative flex h-24 w-24 items-center justify-center rounded-[1.5rem] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_78%,white_22%),color-mix(in_oklch,var(--brand-ink)_92%,black_8%))] text-white shadow-[0_30px_60px_-34px_color-mix(in_oklch,var(--brand-ink)_72%,transparent)]">
                    <.icon name="hero-command-line" class="size-10" />
                  </div>
                </div>
              </div>
            </section>
          </div>
        </section>

        <div class="grid gap-6 xl:grid-cols-[minmax(0,0.95fr)_minmax(0,1.65fr)]" data-bridge-block>
          <article
            id="platform-regents-cli-best-first-command"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6 sm:px-7"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Best first command
            </p>
            <div class="mt-4 flex items-center gap-3 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-4">
              <code class="min-w-0 flex-1 text-[1.04rem] text-[color:var(--foreground)] sm:text-[1.15rem]">
                regents techtree start
              </code>
              <button
                id="platform-regents-cli-best-first-copy"
                type="button"
                phx-hook="ClipboardCopy"
                class="inline-flex h-9 w-9 items-center justify-center rounded-[0.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                aria-label="Copy the best first command"
                title="Copy the best first command"
                data-copy-text="regents techtree start"
              >
                <.icon name="hero-document-duplicate" class="size-4" />
              </button>
            </div>
            <p class="mt-4 max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
              {@techtree_start_intro}
            </p>

            <div class="mt-5 grid gap-3 sm:grid-cols-2">
              <%= for mark <- @best_first_marks do %>
                <section class="rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <div class="flex size-9 shrink-0 items-center justify-center rounded-[0.85rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                      <.icon name={mark.icon} class="size-4" />
                    </div>
                    <div class="space-y-1">
                      <p class="text-sm font-medium text-[color:var(--foreground)]">{mark.title}</p>
                      <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                        {mark.body}
                      </p>
                    </div>
                  </div>
                </section>
              <% end %>
            </div>
          </article>

          <article
            id="platform-regents-cli-work-loop"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6 sm:px-7"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Mental model
            </p>
            <div class="mt-5 grid gap-3 xl:grid-cols-[repeat(4,minmax(0,1fr))]">
              <%= for {loop, index} <- Enum.with_index(@work_loop) do %>
                <div class="flex items-center gap-3">
                  <section class="min-h-[7.75rem] flex-1 rounded-[1.2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-5 text-center">
                    <div class="mx-auto flex size-11 items-center justify-center rounded-full bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_80%,white_20%),color-mix(in_oklch,var(--brand-ink)_92%,black_8%))] text-white">
                      <.icon name={loop.icon} class="size-5" />
                    </div>
                    <p class="mt-4 text-sm font-medium text-[color:var(--foreground)]">
                      {loop.title}
                    </p>
                    <p class="mt-2 text-xs leading-5 text-[color:var(--muted-foreground)]">
                      {loop.body}
                    </p>
                  </section>
                  <div
                    :if={index < length(@work_loop) - 1}
                    class="hidden text-[1.5rem] text-[color:color-mix(in_oklch,var(--foreground)_46%,var(--muted-foreground)_54%)] xl:block"
                    aria-hidden="true"
                  >
                    →
                  </div>
                </div>
              <% end %>
            </div>
          </article>
        </div>

        <div
          class="grid gap-6 xl:grid-cols-[minmax(18rem,0.75fr)_minmax(0,1.1fr)_minmax(18rem,0.8fr)]"
          data-bridge-block
        >
          <article class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6">
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Common rules
            </p>
            <div class="mt-5 space-y-3">
              <%= for rule <- @common_rule_cards do %>
                <section class="flex items-start gap-3 rounded-[1.1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-4">
                  <div class="flex size-10 shrink-0 items-center justify-center rounded-[0.9rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                    <.icon name={rule.icon} class="size-5" />
                  </div>
                  <div class="space-y-1">
                    <p class="text-sm font-medium text-[color:var(--foreground)]">{rule.title}</p>
                    <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">{rule.body}</p>
                  </div>
                </section>
              <% end %>
            </div>
          </article>

          <article
            id="platform-regents-cli-commands"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              First commands to know
            </p>
            <div class="mt-5 grid gap-3 md:grid-cols-2">
              <%= for tile <- @command_tiles do %>
                <section class="rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <div class="flex size-11 shrink-0 items-center justify-center rounded-[0.95rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                      <.icon name={tile.icon} class="size-5" />
                    </div>
                    <div class="min-w-0 space-y-1.5">
                      <p class="text-sm font-medium text-[color:var(--foreground)]">{tile.title}</p>
                      <code class="block truncate text-[0.95rem] text-[color:var(--foreground)]">
                        {tile.command}
                      </code>
                      <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                        {tile.note}
                      </p>
                    </div>
                  </div>
                </section>
              <% end %>
            </div>
            <div class="mt-4 flex justify-end">
              <.link
                navigate={~p"/docs"}
                class="text-sm text-[color:var(--brand-ink)] transition hover:opacity-80"
              >
                See all commands <span aria-hidden="true">→</span>
              </.link>
            </div>
          </article>

          <article
            id="platform-regents-cli-guidance"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Guidance for humans and agents
            </p>
            <div class="mt-5 space-y-3">
              <%= for card <- @guidance_cards do %>
                <section class="rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <div class="flex size-11 shrink-0 items-center justify-center rounded-[0.95rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                      <.icon name={card.icon} class="size-5" />
                    </div>
                    <div class="space-y-2">
                      <p class="text-sm font-medium text-[color:var(--foreground)]">{card.title}</p>
                      <ul class="space-y-1 text-xs leading-5 text-[color:var(--muted-foreground)]">
                        <%= for point <- card.points do %>
                          <li class="flex items-start gap-2">
                            <span class="mt-0.5 text-[color:var(--brand-ink)]">✓</span>
                            <span>{point}</span>
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </section>
              <% end %>
            </div>
            <div class="mt-4 flex justify-end">
              <.link
                navigate={~p"/docs"}
                class="text-sm text-[color:var(--brand-ink)] transition hover:opacity-80"
              >
                Full guidance in the docs <span aria-hidden="true">→</span>
              </.link>
            </div>
          </article>
        </div>

        <section
          data-bridge-block
          class="flex flex-col gap-5 rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-5 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex items-start gap-4">
            <div class="flex size-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--brand-ink)]">
              <.icon name="hero-arrow-down-tray" class="size-5" />
            </div>
            <div class="space-y-1.5">
              <h3 class="text-[1.28rem] font-medium text-[color:var(--foreground)]">
                Install the CLI and get started
              </h3>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Everything runs locally. Your code stays with you.
              </p>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <.link navigate={~p"/docs"} class="pp-link-button pp-link-button-slim">
              View CLI docs <span aria-hidden="true">→</span>
            </.link>
            <.link
              navigate={~p"/app"}
              class="pp-link-button pp-link-button-ghost pp-link-button-slim"
            >
              App setup <span aria-hidden="true">→</span>
            </.link>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
