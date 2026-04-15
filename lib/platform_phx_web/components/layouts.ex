defmodule PlatformPhxWeb.Layouts do
  use PlatformPhxWeb, :html

  alias PlatformPhx.RuntimeConfig

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :chrome, :atom, default: :app
  attr :active_nav, :string, default: nil
  attr :content_class, :string, default: ""
  attr :theme_class, :string, default: "rg-regent-theme-platform"
  attr :current_human, :map, default: nil
  attr :show_wallet_control, :boolean, default: true

  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:nav_sections, nav_sections())
      |> assign(:wallet_bridge_config, Jason.encode!(wallet_bridge_config()))
      |> assign(:wallet_ready?, wallet_ready?())

    ~H"""
    <div
      id="platform-layout-root"
      class={[
        @theme_class,
        "pp-platform-layout min-h-screen"
      ]}
      phx-hook="ColorModeToggle"
    >
      <div
        id="layout-privy-bridge"
        phx-hook="DashboardPrivyBridge"
        phx-update="ignore"
        data-dashboard-config={@wallet_bridge_config}
        class="hidden"
      >
      </div>

      <a
        href="#main-content"
        class="sr-only rounded-xl bg-[color:var(--background)] px-3 py-2 text-sm text-[color:var(--foreground)] shadow focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50"
      >
        Skip to content
      </a>

      <%= if @chrome == :app do %>
        <div class="mx-auto flex min-h-screen max-w-[1600px] gap-3 p-3 lg:p-4">
          <div class="pp-sidebar-column hidden w-72 shrink-0 self-stretch lg:flex lg:flex-col">
            <aside
              data-background-suppress
              class="pp-sidebar-shell relative isolate z-10 rounded-[1.75rem] border border-[color:var(--border)] bg-[color:var(--sidebar)] p-5 shadow-[0_24px_70px_-48px_color-mix(in_oklch,var(--brand-ink)_55%,transparent)]"
            >
              <div class="pp-sidebar-brand-row">
                <.link navigate={~p"/"} class="pp-sidebar-home-link">
                  <div class="flex h-12 w-12 items-center justify-center rounded-2xl border border-[color:var(--border)] bg-[color:var(--card)]">
                    <img
                      src={~p"/images/regents-logo.png"}
                      alt="Regent"
                      class="h-9 w-9 rounded-xl object-cover"
                    />
                  </div>
                  <div class="pp-sidebar-home-copy">
                    <p class="pp-sidebar-home-eyebrow">Home</p>
                    <p class="font-display text-[1.7rem] font-black leading-none">Regents Home</p>
                    <p class="pp-sidebar-home-note">Return to the platform hub</p>
                  </div>
                </.link>
              </div>

              <div class="pp-sidebar-nav-shell">
                <nav class="pp-sidebar-nav" aria-label="Primary">
                  <%= for section <- @nav_sections do %>
                    <section
                      class="pp-sidebar-nav-section"
                      aria-labelledby={"sidebar-nav-section-#{section.id}"}
                    >
                      <div class="pp-sidebar-nav-heading">
                        <p id={"sidebar-nav-section-#{section.id}"} class="pp-sidebar-nav-label">
                          {section.label}
                        </p>
                        <p class="pp-sidebar-nav-copy">{section.copy}</p>
                      </div>

                      <div class="space-y-2">
                        <%= for item <- section.items do %>
                          <%= if item.kind == :internal do %>
                            <.nav_link
                              current={@active_nav == item.key}
                              href={item.href}
                              label={item.label}
                            />
                          <% else %>
                            <.external_nav_link href={item.href} label={item.label} />
                          <% end %>
                        <% end %>
                      </div>
                    </section>
                  <% end %>
                </nav>

                <div id="sidebar-community" class="pp-sidebar-community" phx-hook="SidebarCommunity">
                  <button
                    type="button"
                    class="pp-sidebar-community-toggle"
                    data-community-toggle
                    aria-expanded="false"
                    aria-controls="sidebar-community-drawer"
                  >
                    <span class="pp-sidebar-community-label">Community</span>
                    <span
                      aria-hidden="true"
                      class="pp-sidebar-community-icon"
                      data-community-icon
                    >
                      ↓
                    </span>
                  </button>

                  <div
                    id="sidebar-community-drawer"
                    class="pp-sidebar-community-drawer"
                    data-community-panel
                    hidden
                  >
                    <div class="pp-sidebar-community-grid">
                      <.community_links />
                    </div>
                  </div>
                </div>
              </div>
            </aside>
          </div>

          <div class={[
            "pp-platform-content-shell flex min-w-0 flex-1 flex-col rounded-[1.75rem] border border-[color:var(--border)] shadow-[0_26px_70px_-44px_color-mix(in_oklch,var(--brand-ink)_55%,transparent)]",
            @active_nav == "token-info" && "pp-platform-content-shell--token"
          ]}>
            <div
              data-background-suppress
              class="pp-mobile-nav-shell lg:hidden"
            >
              <div class="pp-mobile-nav-header">
                <.link navigate={~p"/"} class="pp-mobile-home-link">
                  <span class="pp-mobile-home-mark">
                    <img
                      src={~p"/images/regents-logo.png"}
                      alt=""
                      class="h-8 w-8 rounded-xl object-cover"
                    />
                  </span>
                  <span class="pp-mobile-home-copy">
                    <span class="pp-mobile-home-eyebrow">Home</span>
                    <span class="pp-mobile-home-title">Regents Home</span>
                    <span class="pp-mobile-home-note">Return to the platform hub</span>
                  </span>
                </.link>

                <%= if @show_wallet_control do %>
                  <.layout_wallet_control
                    current_human={@current_human}
                    wallet_ready?={@wallet_ready?}
                    config={@wallet_bridge_config}
                    mode={:mobile}
                  />
                <% end %>
              </div>

              <div class="pp-mobile-nav-sections">
                <%= for section <- @nav_sections do %>
                  <section
                    class="pp-mobile-nav-section"
                    aria-labelledby={"mobile-nav-section-#{section.id}"}
                  >
                    <div class="pp-mobile-nav-section-head">
                      <p id={"mobile-nav-section-#{section.id}"} class="pp-mobile-nav-section-label">
                        {section.label}
                      </p>
                      <p class="pp-mobile-nav-section-copy">{section.copy}</p>
                    </div>

                    <nav
                      class="pp-mobile-nav-rail"
                      aria-label={"#{section.label} mobile navigation"}
                    >
                      <%= for item <- section.items do %>
                        <%= if item.kind == :internal do %>
                          <.mobile_nav_link
                            current={@active_nav == item.key}
                            href={item.href}
                            label={item.label}
                          />
                        <% else %>
                          <.mobile_external_nav_link href={item.href} label={item.label} />
                        <% end %>
                      <% end %>
                    </nav>
                  </section>
                <% end %>
              </div>
            </div>

            <header
              data-background-suppress
              class="pp-chrome-header"
            >
              <div class="pp-chrome-head">
                <p class="pp-chrome-eyebrow">
                  {chrome_eyebrow(@active_nav)}
                </p>
                <h1 class="pp-chrome-title">{chrome_title(@active_nav)}</h1>
                <p class="pp-chrome-note">{chrome_note(@active_nav)}</p>
              </div>

              <div class="pp-chrome-actions">
                <.link navigate={~p"/"} class="pp-chrome-home-link">
                  Home <span aria-hidden="true">→</span>
                </.link>

                <%= if @show_wallet_control do %>
                  <.layout_wallet_control
                    current_human={@current_human}
                    wallet_ready?={@wallet_ready?}
                    config={@wallet_bridge_config}
                    mode={:desktop}
                  />
                <% end %>
              </div>
            </header>

            <main
              id="main-content"
              data-background-suppress
              class={["min-h-0 flex-1 overflow-y-auto p-4 sm:p-5 lg:p-6", @content_class]}
              tabindex="-1"
            >
              {render_slot(@inner_block)}
            </main>

            <footer
              data-background-suppress
              class="flex flex-wrap items-center justify-between gap-3 border-t border-[color:var(--border)] px-5 py-4 text-sm text-[color:var(--muted-foreground)]"
            >
              <p>&copy; Regents Labs 2026</p>
              <.footer_social_links variant={:labelled} />
            </footer>
          </div>
        </div>
      <% else %>
        <div class="mx-auto flex min-h-screen max-w-[1600px] flex-col gap-4 p-3 sm:p-4">
          <%= if @show_wallet_control do %>
            <div class="flex justify-end">
              <.layout_wallet_control
                current_human={@current_human}
                wallet_ready?={@wallet_ready?}
                config={@wallet_bridge_config}
                mode={:floating}
              />
            </div>
          <% end %>

          <main
            id="main-content"
            class={["min-h-0 flex-1", @content_class]}
            tabindex="-1"
          >
            {render_slot(@inner_block)}
          </main>
        </div>
      <% end %>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :current_human, :map, default: nil
  attr :wallet_ready?, :boolean, required: true
  attr :config, :string, required: true
  attr :mode, :atom, default: :desktop

  defp layout_wallet_control(assigns) do
    ~H"""
    <div
      id={"layout-wallet-control-#{@mode}"}
      phx-hook="DashboardWallet"
      phx-update="ignore"
      data-dashboard-config={@config}
      data-wallet-signed-in={to_string(not is_nil(@current_human))}
      data-wallet-address={@current_human && @current_human.wallet_address}
      class={[
        "pp-wallet-shell",
        @mode == :desktop && "hidden lg:flex",
        @mode == :mobile && "flex lg:hidden",
        @mode == :floating && "flex"
      ]}
    >
      <button
        type="button"
        data-wallet-sign-in
        class="pp-wallet-pill pp-wallet-pill-primary"
        disabled={!@wallet_ready?}
      >
        Sign In
      </button>

      <div data-wallet-connected class="pp-wallet-connected-shell hidden">
        <button
          type="button"
          data-wallet-trigger
          class="pp-wallet-pill pp-wallet-pill-secondary"
          aria-expanded="false"
          aria-controls={"layout-wallet-drawer-#{@mode}"}
        >
          <span class="pp-wallet-pill-dot" aria-hidden="true"></span>
          <span>Wallet Connected</span>
          <span class="pp-wallet-pill-caret" data-wallet-caret aria-hidden="true">↓</span>
        </button>

        <div
          id={"layout-wallet-drawer-#{@mode}"}
          data-wallet-drawer
          class="pp-wallet-drawer"
          hidden
        >
          <div data-wallet-drawer-inner class="pp-wallet-drawer-inner">
            <div class="pp-wallet-drawer-row">
              <p class="pp-wallet-drawer-label">Wallet</p>
              <div class="pp-wallet-address-row">
                <span data-wallet-address-text class="pp-wallet-address-text">
                  {abbreviated_wallet(@current_human && @current_human.wallet_address)}
                </span>
                <button
                  type="button"
                  data-wallet-copy
                  class="pp-wallet-icon-button"
                  aria-label="Copy wallet address"
                  title="Copy full wallet address"
                >
                  <span class="pp-wallet-copy-icon" aria-hidden="true">
                    <.icon name="hero-document-duplicate" class="size-4" />
                  </span>
                  <span data-wallet-copy-check class="pp-wallet-copy-check" aria-hidden="true">
                    <.icon name="hero-check" class="size-4" />
                  </span>
                </button>
              </div>
            </div>

            <button
              type="button"
              data-wallet-disconnect
              class="pp-wallet-drawer-action"
            >
              Disconnect
            </button>
          </div>
        </div>
      </div>

      <p
        data-dashboard-wallet-notice
        data-notice-style="compact"
        class="hidden text-sm text-[color:var(--muted-foreground)]"
      >
      </p>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      aria-current={if @current, do: "page", else: nil}
      class={[
        "pp-sidebar-nav-link",
        @current &&
          "pp-sidebar-nav-link-current",
        !@current &&
          "pp-sidebar-nav-link-idle"
      ]}
    >
      <span class="pp-sidebar-nav-link-copy">
        <span class="pp-sidebar-nav-link-mark" aria-hidden="true"></span>
        <span>{@label}</span>
      </span>
      <span aria-hidden="true" class="pp-sidebar-nav-link-arrow">→</span>
    </.link>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true

  defp external_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      target="_blank"
      rel="noreferrer"
      class="pp-sidebar-nav-link pp-sidebar-nav-link-idle"
    >
      <span class="pp-sidebar-nav-link-copy">
        <span class="pp-sidebar-nav-link-mark pp-sidebar-nav-link-mark-external" aria-hidden="true">
        </span>
        <span>{@label}</span>
      </span>
      <span class="pp-sidebar-nav-link-exit">
        <span>External</span>
        <span aria-hidden="true">↗</span>
      </span>
    </a>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp mobile_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      aria-current={if @current, do: "page", else: nil}
      class={[
        "pp-mobile-nav-link",
        @current && "pp-mobile-nav-link-current"
      ]}
    >
      <span>{@label}</span>
      <span aria-hidden="true">→</span>
    </.link>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true

  defp mobile_external_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      target="_blank"
      rel="noreferrer"
      class="pp-mobile-nav-link pp-mobile-nav-link-external"
    >
      <span>{@label}</span>
      <span class="pp-mobile-nav-link-exit">
        <span>External</span>
        <span aria-hidden="true">↗</span>
      </span>
    </a>
    """
  end

  defp community_links(assigns) do
    ~H"""
    <a
      href="https://x.com/regents_sh"
      target="_blank"
      rel="noreferrer"
      class="pp-sidebar-community-link"
      aria-label="Regents Labs on X"
      title="Regents Labs on X"
    >
      <.x_mark class="pp-social-mark" />
    </a>

    <a
      href="https://farcaster.xyz/regent"
      target="_blank"
      rel="noreferrer"
      class="pp-sidebar-community-link"
      aria-label="Regent on Farcaster"
      title="Regent on Farcaster"
    >
      <img src={~p"/images/farcastericon.png"} alt="" class="pp-home-footer-icon-image" />
    </a>

    <a
      href="https://discord.gg/regents"
      target="_blank"
      rel="noreferrer"
      class="pp-sidebar-community-link"
      aria-label="Regents on Discord"
      title="Regents on Discord"
    >
      <.discord_mark class="pp-social-mark" />
    </a>

    <a
      href="https://github.com/orgs/regent-ai/repositories"
      target="_blank"
      rel="noreferrer"
      class="pp-sidebar-community-link"
      aria-label="Regents Labs GitHub"
      title="Regents Labs GitHub"
    >
      <.github_mark class="size-5" />
    </a>
    """
  end

  attr :variant, :atom, default: :compact

  def footer_social_links(assigns) do
    ~H"""
    <div class="pp-home-footer-links" aria-label="Regents Labs footer social links">
      <button
        id="platform-footer-voxel-classic"
        type="button"
        class={[
          "pp-home-footer-link pp-footer-voxel-toggle",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        phx-hook="FooterVoxel"
        data-color-mode-cycle
        data-background-suppress
        aria-label="Toggle light and dark mode"
        aria-pressed="false"
        title="Toggle light and dark mode"
      >
        <span class="pp-footer-voxel-scene" data-footer-voxel-scene aria-hidden="true"></span>
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">Theme</span>
      </button>

      <a
        href="https://x.com/regents_sh"
        target="_blank"
        rel="noreferrer"
        class={[
          "pp-home-footer-link",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        data-background-suppress
        aria-label="Regents Labs on X"
        title="Regents Labs on X"
      >
        <.x_mark class="pp-social-mark" />
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">X</span>
      </a>

      <a
        href="https://farcaster.xyz/regent"
        target="_blank"
        rel="noreferrer"
        class={[
          "pp-home-footer-link",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        data-background-suppress
        aria-label="Regent on Farcaster"
        title="Regent on Farcaster"
      >
        <img src={~p"/images/farcastericon.png"} alt="" class="pp-home-footer-icon-image" />
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">Farcaster</span>
      </a>

      <a
        href="https://discord.gg/regents"
        target="_blank"
        rel="noreferrer"
        class={[
          "pp-home-footer-link",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        data-background-suppress
        aria-label="Regents on Discord"
        title="Regents on Discord"
      >
        <.discord_mark class="pp-social-mark" />
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">Discord</span>
      </a>

      <a
        href="https://github.com/orgs/regent-ai/repositories"
        target="_blank"
        rel="noreferrer"
        class={[
          "pp-home-footer-link",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        data-background-suppress
        aria-label="Regents Labs GitHub"
        title="Regents Labs GitHub"
      >
        <.github_mark class="size-5" />
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">GitHub</span>
      </a>

      <a
        href="https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"
        target="_blank"
        rel="noreferrer"
        class={[
          "pp-home-footer-link",
          @variant == :labelled && "pp-home-footer-link-labelled"
        ]}
        data-background-suppress
        aria-label="View $REGENT on GeckoTerminal"
        title="View $REGENT on GeckoTerminal"
      >
        <img src={~p"/images/geckoterminallogo.png"} alt="" class="pp-home-footer-icon-image" />
        <span :if={@variant == :labelled} class="pp-home-footer-link-text">GeckoTerminal</span>
      </a>
    </div>
    """
  end

  defp chrome_eyebrow("overview"), do: "Start here"
  defp chrome_eyebrow("services"), do: "Shared services"
  defp chrome_eyebrow("agent-formation"), do: "Launch a company"
  defp chrome_eyebrow("bug-report"), do: "Public operator ledger"
  defp chrome_eyebrow("techtree"), do: "Research surface"
  defp chrome_eyebrow("autolaunch"), do: "Capital surface"
  defp chrome_eyebrow("regent-cli"), do: "Terminal rail"
  defp chrome_eyebrow("token-info"), do: "Revenue token"
  defp chrome_eyebrow("shader"), do: "Shader registry"
  defp chrome_eyebrow(_), do: "Platform hub"

  defp chrome_title("overview"), do: "See how the platform fits together"
  defp chrome_title("services"), do: "Manage names, redemptions, and wallet setup"
  defp chrome_title("agent-formation"), do: "Move from a claimed name to a live company"
  defp chrome_title("bug-report"), do: "Review public bugs and fixes"
  defp chrome_title("techtree"), do: "Publish work other agents can inspect"
  defp chrome_title("autolaunch"), do: "Raise backing for useful agent work"
  defp chrome_title("regent-cli"), do: "Work with Regents from the command line"
  defp chrome_title("token-info"), do: "Understand how REGENT flows through the platform"
  defp chrome_title("shader"), do: "Browse shared shader work"
  defp chrome_title(_), do: "Regents Home"

  defp chrome_note("overview"),
    do: "Use this page to understand the product surfaces before you jump into a task."

  defp chrome_note("services"),
    do: "This is the shared setup area for names, passes, and wallet-linked access."

  defp chrome_note("agent-formation"),
    do: "Use this flow when you are ready to take a claimed name live."

  defp chrome_note("bug-report"),
    do: "Follow open issues, fixes, and operator history in one public ledger."

  defp chrome_note("techtree"),
    do: "Open the shared research graph to publish, inspect, and improve useful work."

  defp chrome_note("autolaunch"),
    do: "Review launch paths, auctions, and funding routes for agent businesses."

  defp chrome_note("regent-cli"),
    do: "Keep the terminal workflow close when you want to operate without the browser."

  defp chrome_note("token-info"),
    do: "Review how the platform token links product income, fees, and revshare."

  defp chrome_note("shader"),
    do: "Browse the shared shader catalog and open the examples that matter."

  defp chrome_note(_), do: "Open the route you need, then get back to work quickly."

  defp wallet_bridge_config do
    %{
      privyAppId: RuntimeConfig.privy_app_id(),
      privyClientId: RuntimeConfig.privy_client_id(),
      privySession: "/api/auth/privy/session"
    }
  end

  defp wallet_ready? do
    RuntimeConfig.privy_app_id() not in [nil, ""] and
      RuntimeConfig.privy_client_id() not in [nil, ""]
  end

  defp abbreviated_wallet(nil), do: ""

  defp abbreviated_wallet(wallet_address) when is_binary(wallet_address) do
    trimmed = String.trim(wallet_address)

    if String.length(trimmed) <= 10 do
      trimmed
    else
      String.slice(trimmed, 0, 6) <> "..." <> String.slice(trimmed, -4, 4)
    end
  end

  defp nav_sections do
    [
      %{
        id: "orientation",
        label: "Get Oriented",
        copy: "Start with the platform map and the shared token view.",
        items: [
          %{kind: :internal, key: "overview", href: "/overview", label: "Overview"},
          %{kind: :internal, key: "token-info", href: "/token-info", label: "Platform Token"}
        ]
      },
      %{
        id: "operate",
        label: "Build and Operate",
        copy: "Use the shared rails for services, launches, and terminal work.",
        items: [
          %{kind: :internal, key: "services", href: "/services", label: "Services"},
          %{
            kind: :internal,
            key: "agent-formation",
            href: "/agent-formation",
            label: "Agent Formation"
          },
          %{kind: :internal, key: "regent-cli", href: "/regent-cli", label: "Regent CLI"},
          %{kind: :internal, key: "bug-report", href: "/bug-report", label: "Bug Report"}
        ]
      },
      %{
        id: "product-surfaces",
        label: "Product Surfaces",
        copy: "Branch into the public research and capital routes.",
        items: [
          %{kind: :internal, key: "techtree", href: "/techtree", label: "Techtree"},
          %{kind: :internal, key: "autolaunch", href: "/autolaunch", label: "Autolaunch"}
        ]
      },
      %{
        id: "outside",
        label: "Outside Regents",
        copy: "Open public updates and source material in a new tab.",
        items: [
          %{kind: :external, href: "https://news.regents.sh", label: "News"},
          %{
            kind: :external,
            href: "https://github.com/orgs/regent-ai/repositories",
            label: "GitHub"
          }
        ]
      }
    ]
  end

  attr :class, :string, default: nil

  defp x_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class={@class}>
      <path d="M18.244 2.25h3.308l-7.227 8.26L23 21.75h-6.828l-5.347-6.79-5.94 6.79H1.577l7.73-8.835L1 2.25h7.002l4.833 6.133zM17.083 19.77h1.833L7.084 4.126H5.117z" />
    </svg>
    """
  end

  defp discord_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class={@class}>
      <path d="M20.317 4.37A19.79 19.79 0 0 0 15.43 2.855a13.79 13.79 0 0 0-.66 1.357 18.27 18.27 0 0 0-5.538 0 13.68 13.68 0 0 0-.67-1.357A19.74 19.74 0 0 0 3.678 4.37C.534 9.09-.32 13.693.099 18.23a19.9 19.9 0 0 0 6.06 3.078 14.9 14.9 0 0 0 1.298-2.11 12.92 12.92 0 0 1-2.04-.98c.172-.128.341-.262.505-.4a14.1 14.1 0 0 0 12.163 0c.165.138.334.272.505.4a12.9 12.9 0 0 1-2.042.981 14.2 14.2 0 0 0 1.299 2.109 19.86 19.86 0 0 0 6.061-3.078c.492-5.261-.84-9.821-3.59-13.86ZM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.334.948-2.419 2.157-2.419 1.219 0 2.175 1.095 2.157 2.419 0 1.334-.948 2.419-2.157 2.419Zm7.974 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.334.948-2.419 2.157-2.419 1.219 0 2.175 1.095 2.157 2.419 0 1.334-.938 2.419-2.157 2.419Z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  defp github_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class={@class}>
      <path d="M12 2C6.48 2 2 6.58 2 12.22c0 4.5 2.87 8.31 6.84 9.66.5.1.68-.22.68-.49 0-.24-.01-1.05-.01-1.91-2.78.62-3.37-1.21-3.37-1.21-.45-1.19-1.11-1.5-1.11-1.5-.91-.64.07-.63.07-.63 1 .08 1.53 1.06 1.53 1.06.9 1.56 2.35 1.11 2.92.85.09-.67.35-1.11.63-1.37-2.22-.26-4.56-1.14-4.56-5.08 0-1.12.39-2.04 1.03-2.76-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05A9.35 9.35 0 0 1 12 6.84c.85 0 1.71.12 2.51.35 1.91-1.33 2.75-1.05 2.75-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.64 1.03 2.76 0 3.95-2.34 4.81-4.58 5.07.36.32.68.95.68 1.91 0 1.38-.01 2.49-.01 2.83 0 .27.18.59.69.49A10.24 10.24 0 0 0 22 12.22C22 6.58 17.52 2 12 2Z" />
    </svg>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
