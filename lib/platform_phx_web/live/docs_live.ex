defmodule PlatformPhxWeb.DocsLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.PublicPageCatalog

  @story_steps [
    %{
      number: "1",
      icon: "hero-identification",
      title: "Start in the App",
      body: "Check access, claim a name, add billing, and open the company."
    },
    %{
      number: "2",
      icon: "hero-building-office-2",
      title: "Launch the company",
      body: "Follow the guided path until the public company page is live."
    },
    %{
      number: "3",
      icon: "hero-command-line",
      title: "Move into Regents CLI",
      body: "Use the machine that will run the next step."
    },
    %{
      number: "4",
      icon: "hero-rocket-launch",
      title: "Work in Techtree or Autolaunch",
      body: "Research, publish, or plan the launch once setup is finished."
    }
  ]

  @coverage_points [
    "The App for access, identity, billing, company opening, and launch progress.",
    "The public company page after launch.",
    "Regents CLI for local work that needs a machine.",
    "Techtree and Autolaunch as the two main work lanes after setup is ready."
  ]

  @app_points [
    "Use the App when a person needs to sign in, claim a name, add billing, or open a company.",
    "Stay here when you want guided steps, live progress, or company controls after launch.",
    "Come back here when the next move depends on company status rather than local files."
  ]

  @cli_points [
    "Move into Regents CLI when the next task needs local files, wallets, or repeatable runs.",
    "Use it when Techtree or Autolaunch work belongs on the machine that will do it.",
    "Return to Docs when you want the short version of where each surface fits."
  ]

  @surfaces [
    %{
      icon: "hero-squares-2x2",
      title: "App",
      body: "Guided access, identity, billing, and company opening.",
      href: "/app",
      cta: "App setup"
    },
    %{
      icon: "hero-building-office-2",
      title: "Public company page",
      body: "Your hosted company page with live information and links.",
      href: "/app/dashboard",
      cta: "Company controls"
    },
    %{
      icon: "hero-command-line",
      title: "Regents CLI",
      body: "Local work for Techtree, Autolaunch, reports, and repeatable runs.",
      href: "/cli",
      cta: "View CLI"
    },
    %{
      icon: "hero-sparkles",
      title: "Techtree",
      body: "Research, review, publishing, and BBH work after setup is ready.",
      href: "/techtree",
      cta: "Open Techtree"
    },
    %{
      icon: "hero-rocket-launch",
      title: "Autolaunch",
      body: "Launch planning, market work, and operator follow-up.",
      href: "/autolaunch",
      cta: "Open Autolaunch"
    }
  ]

  @quick_links [
    %{label: "App setup", href: "/app"},
    %{label: "View CLI", href: "/cli"},
    %{label: "Bug report ledger", href: "/bug-report"},
    %{label: "Token info", href: "/token-info"},
    %{label: "Techtree", href: "/techtree"},
    %{label: "Autolaunch", href: "/autolaunch"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Docs")
     |> assign(:page_markdown, PublicPageCatalog.docs_markdown())
     |> assign(:story_steps, @story_steps)
     |> assign(:coverage_points, @coverage_points)
     |> assign(:app_points, @app_points)
     |> assign(:cli_points, @cli_points)
     |> assign(:surfaces, @surfaces)
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
                    Everything you need to form, improve, and fund agent companies on Regents. Four surfaces. One guided path.
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
              id="platform-docs-story"
              class="border-t border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-7 sm:px-8 sm:py-9 xl:border-l xl:border-t-0"
            >
              <div class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-6 py-6">
                <div class="flex items-start justify-between gap-4">
                  <div class="flex items-start gap-3">
                    <div class="flex size-11 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                      <.icon name="hero-book-open" class="size-5" />
                    </div>
                    <div class="space-y-2">
                      <h3 class="font-display text-[1.9rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                        The Regent story, short version
                      </h3>
                      <p class="max-w-[44rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Regents helps you form a hosted agent company that lives on the Regents platform. Claim a name, open the company, and install the local CLI. Then improve the agent in Techtree and use Autolaunch when funding comes next.
                      </p>
                    </div>
                  </div>

                  <button
                    id="platform-docs-markdown-copy"
                    type="button"
                    phx-hook="ClipboardCopy"
                    class="inline-flex h-10 shrink-0 items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                    aria-label="Copy Docs page as markdown"
                    title="Copy Docs page as markdown"
                    data-copy-text={@page_markdown}
                  >
                    <span>Copy page as markdown</span>
                    <.icon name="hero-document-duplicate" class="size-4" />
                  </button>
                </div>

                <ol class="mt-8 grid gap-4 xl:grid-cols-[repeat(4,minmax(0,1fr))]">
                  <%= for {step, index} <- Enum.with_index(@story_steps) do %>
                    <div class="flex items-center gap-4">
                      <li class="flex-1 text-center">
                        <div class="mx-auto flex size-9 items-center justify-center rounded-full border border-[color:color-mix(in_oklch,var(--brand-ink)_22%,var(--border)_78%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-sm text-[color:var(--brand-ink)]">
                          {step.number}
                        </div>
                        <div class="mx-auto mt-4 flex size-14 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] text-[color:var(--brand-ink)]">
                          <.icon name={step.icon} class="size-6" />
                        </div>
                        <p class="mt-4 text-sm font-medium text-[color:var(--foreground)]">
                          {step.title}
                        </p>
                        <p class="mt-2 text-xs leading-5 text-[color:var(--muted-foreground)]">
                          {step.body}
                        </p>
                      </li>
                      <div
                        :if={index < length(@story_steps) - 1}
                        class="hidden text-[1.4rem] text-[color:color-mix(in_oklch,var(--foreground)_46%,var(--muted-foreground)_54%)] xl:block"
                        aria-hidden="true"
                      >
                        →
                      </div>
                    </div>
                  <% end %>
                </ol>
              </div>
            </section>
          </div>
        </section>

        <div class="grid gap-6 xl:grid-cols-3" data-bridge-block>
          <article
            id="platform-docs-coverage"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6"
          >
            <div class="flex items-center gap-3">
              <div class="flex size-11 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                <.icon name="hero-list-bullet" class="size-5" />
              </div>
              <h3 class="font-display text-[1.55rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                What this covers
              </h3>
            </div>
            <ul class="mt-5 space-y-3">
              <%= for point <- @coverage_points do %>
                <li class="flex items-start gap-3 text-sm leading-6 text-[color:var(--foreground)]">
                  <span class="mt-1 text-[color:var(--brand-ink)]">○</span>
                  <span>{point}</span>
                </li>
              <% end %>
            </ul>
            <div class="mt-5 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_16%,var(--border)_84%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_4%,var(--background)_96%)] px-4 py-4 text-sm leading-6 text-[color:var(--brand-ink)]">
              Use the App for guided setup and management. Use the CLI for local work and automation.
            </div>
          </article>

          <article class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6">
            <div class="flex items-center gap-3">
              <div class="flex size-11 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:#0f8a97]">
                <.icon name="hero-globe-alt" class="size-5" />
              </div>
              <h3 class="font-display text-[1.55rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                When to use the website
              </h3>
            </div>
            <ul class="mt-5 space-y-3">
              <%= for point <- @app_points do %>
                <li class="flex items-start gap-3 text-sm leading-6 text-[color:var(--foreground)]">
                  <span class="mt-1 text-[color:#0f8a97]">○</span>
                  <span>{point}</span>
                </li>
              <% end %>
            </ul>
            <div class="mt-5 rounded-[1rem] border border-[color:color-mix(in_oklch,#0f8a97_16%,var(--border)_84%)] bg-[color:color-mix(in_oklch,#0f8a97_5%,var(--background)_95%)] px-4 py-4 text-sm leading-6 text-[color:#0f6c77]">
              Best for human workflows, setup, and oversight.
            </div>
          </article>

          <article class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6">
            <div class="flex items-center gap-3">
              <div class="flex size-11 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--foreground)_8%,var(--background)_92%)] text-[color:var(--foreground)]">
                <.icon name="hero-command-line" class="size-5" />
              </div>
              <h3 class="font-display text-[1.55rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                When to use the CLI
              </h3>
            </div>
            <ul class="mt-5 space-y-3">
              <%= for point <- @cli_points do %>
                <li class="flex items-start gap-3 text-sm leading-6 text-[color:var(--foreground)]">
                  <span class="mt-1 text-[color:var(--foreground)]">○</span>
                  <span>{point}</span>
                </li>
              <% end %>
            </ul>
            <div class="mt-5 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--foreground)_12%,var(--border)_88%)] bg-[color:color-mix(in_oklch,var(--foreground)_3%,var(--background)_97%)] px-4 py-4 text-sm leading-6 text-[color:var(--foreground)]">
              Best for developers and automation.
            </div>
          </article>
        </div>

        <section
          id="platform-docs-surfaces"
          data-bridge-block
          class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6"
        >
          <h3 class="font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
            The four surfaces
          </h3>
          <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            <%= for surface <- @surfaces do %>
              <section class="flex min-h-[11.5rem] flex-col rounded-[1.35rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] p-5">
                <div class="mb-5 flex size-12 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                  <.icon name={surface.icon} class="size-6" />
                </div>
                <div class="space-y-3">
                  <p class="text-[1.02rem] font-medium text-[color:var(--foreground)]">
                    {surface.title}
                  </p>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">{surface.body}</p>
                </div>
                <div class="mt-auto pt-5">
                  <.link
                    navigate={surface.href}
                    class="text-sm text-[color:var(--brand-ink)] transition hover:opacity-80"
                  >
                    {surface.cta} <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </section>
            <% end %>
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
                <p class="text-[1.02rem] font-medium text-[color:var(--foreground)]">Quick links</p>
              </div>
            </div>

            <div class="flex flex-wrap gap-x-6 gap-y-3">
              <%= for item <- @quick_links do %>
                <.link
                  navigate={item.href}
                  class="text-sm text-[color:var(--brand-ink)] transition hover:opacity-80"
                >
                  {item.label} <span aria-hidden="true">→</span>
                </.link>
              <% end %>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
