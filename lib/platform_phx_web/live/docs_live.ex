defmodule PlatformPhxWeb.DocsLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.PublicPageCatalog

  @surface_links [
    %{title: "App", href: "/app"},
    %{title: "Public company page", href: "/app/dashboard"},
    %{title: "Regents CLI", href: "/cli"},
    %{title: "Techtree", href: "/techtree"},
    %{title: "Autolaunch", href: "/autolaunch"}
  ]

  @quick_links [
    %{label: "App setup", href: "/app"},
    %{label: "View CLI", href: "/cli"},
    %{label: "Bug report ledger", href: "/bug-report"},
    %{label: "Token info", href: "/token-info"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Docs")
     |> assign(:page_markdown, PublicPageCatalog.docs_markdown())
     |> assign(:surface_links, @surface_links)
     |> assign(:quick_links, @quick_links)}
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
      <div
        id="platform-docs-shell"
        class="rg-regent-theme-platform space-y-6"
        phx-hook="BridgeReveal"
      >
        <section
          id="platform-docs-hero"
          data-bridge-block
          class="overflow-hidden rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)]"
        >
          <div class="grid gap-0 xl:grid-cols-[minmax(0,0.88fr)_minmax(0,1.12fr)]">
            <div class="space-y-8 px-6 py-7 sm:px-8 sm:py-9">
              <div class="space-y-5">
                <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
                  Docs
                </p>
                <div class="space-y-4">
                  <h2 class="font-display text-[clamp(3.4rem,8vw,6rem)] leading-[0.88] tracking-[-0.08em] text-[color:var(--foreground)]">
                    Start here
                  </h2>
                  <p class="max-w-[34rem] text-[1.18rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_76%,var(--muted-foreground)_24%)]">
                    Use this page to choose the next place to work. The longer reference copy is available through the markdown button.
                  </p>
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-3">
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
            </div>

            <section
              id="platform-docs-index"
              class="border-t border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-7 sm:px-8 sm:py-9 xl:border-l xl:border-t-0"
            >
              <div class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-6 py-6">
                <div class="flex flex-col items-start gap-4 sm:flex-row sm:justify-between">
                  <div class="space-y-2">
                    <h3 class="font-display text-[1.9rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                      Where to go next
                    </h3>
                    <p class="max-w-[44rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                      Pick the surface that matches the work, then open the full reference copy if you need the longer version.
                    </p>
                  </div>

                  <button
                    id="platform-docs-markdown-copy"
                    type="button"
                    phx-hook="ClipboardCopy"
                    class="inline-flex h-10 max-w-full shrink-0 items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                    aria-label="Copy Docs page as markdown"
                    title="Copy Docs page as markdown"
                    data-copy-text={@page_markdown}
                  >
                    <span class="truncate">Copy page as markdown</span>
                    <.icon name="hero-document-duplicate" class="size-4" />
                  </button>
                </div>

                <div class="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
                  <%= for link <- @surface_links do %>
                    <section class="rounded-[1.35rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] p-5">
                      <p class="text-[1.02rem] font-medium text-[color:var(--foreground)]">
                        {link.title}
                      </p>
                      <div class="mt-5">
                        <.link
                          navigate={link.href}
                          class="text-sm text-[color:var(--brand-ink)] transition hover:opacity-80"
                        >
                          Open <span aria-hidden="true">→</span>
                        </.link>
                      </div>
                    </section>
                  <% end %>
                </div>
              </div>
            </section>
          </div>
        </section>

        <section
          id="platform-docs-quick-links"
          data-bridge-block
          class="rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] px-5 py-4"
        >
          <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div class="flex items-center gap-3">
              <div class="flex size-11 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                <.icon name="hero-link" class="size-5" />
              </div>
              <div>
                <p class="text-[1.02rem] font-medium text-[color:var(--foreground)]">
                  Quick links
                </p>
              </div>
            </div>

            <div class="grid w-full gap-3 sm:grid-cols-2 xl:max-w-[42rem] xl:grid-cols-4">
              <%= for item <- @quick_links do %>
                <.link
                  navigate={item.href}
                  class="group flex items-center justify-between gap-3 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)] hover:bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)]"
                >
                  <span>{item.label}</span>
                  <span
                    aria-hidden="true"
                    class="text-[color:var(--brand-ink)] transition group-hover:translate-x-0.5"
                  >
                    →
                  </span>
                </.link>
              <% end %>
            </div>
          </div>

          <div class="mt-5 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_16%,var(--border)_84%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_4%,var(--background)_96%)] px-4 py-4 text-sm leading-6 text-[color:var(--brand-ink)]">
            Use the App for setup and company control. Use the CLI for local work and repeatable runs.
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
