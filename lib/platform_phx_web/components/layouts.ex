defmodule PlatformPhxWeb.Layouts do
  use PlatformPhxWeb, :html

  alias PlatformPhx.RuntimeConfig
  alias PlatformPhxWeb.LayoutHelpers

  embed_templates("layouts/*")

  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  attr(:chrome, :atom, default: :app)
  attr(:active_nav, :string, default: nil)
  attr(:header_eyebrow, :string, default: nil)
  attr(:header_title, :string, default: nil)
  attr(:content_class, :string, default: "")
  attr(:theme_class, :string, default: "rg-regent-theme-platform")
  attr(:current_human, :map, default: nil)
  attr(:show_wallet_control, :boolean, default: true)

  slot(:inner_block, required: true)

  def app(assigns) do
    quick_search_items = LayoutHelpers.quick_search_items()

    assigns =
      assigns
      |> assign(:nav_items, LayoutHelpers.nav_items())
      |> assign(:quick_search_items, quick_search_items)
      |> assign(:quick_search_items_json, Jason.encode!(quick_search_items))
      |> assign(
        :shell_eyebrow,
        LayoutHelpers.header_eyebrow(assigns.header_eyebrow, assigns.active_nav)
      )
      |> assign(:shell_title, LayoutHelpers.shell_title(assigns.header_title, assigns.active_nav))
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

      <%= if @show_wallet_control do %>
        <div
          id="layout-wallet-controller"
          phx-hook="DashboardWallet"
          phx-update="ignore"
          data-dashboard-config={@wallet_bridge_config}
          data-wallet-signed-in={to_string(not is_nil(@current_human))}
          data-wallet-address={@current_human && @current_human.wallet_address}
          class="hidden"
        >
        </div>
      <% end %>

      <a
        href="#main-content"
        class="sr-only rounded-xl bg-[color:var(--background)] px-3 py-2 text-sm text-[color:var(--foreground)] shadow focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50"
      >
        Skip to content
      </a>

      <%= if @chrome == :app do %>
        <div class="mx-auto max-w-[1550px] p-3 sm:p-4">
          <div
            id="platform-shell-frame"
            class={[
              "relative flex min-h-[calc(100vh-1.5rem)] overflow-hidden rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--border)_86%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] shadow-[0_28px_72px_-48px_color-mix(in_oklch,var(--brand-ink)_28%,transparent)]",
              @active_nav == "token-info" && "pp-platform-content-shell--token"
            ]}
          >
            <aside
              id="platform-shell-sidebar"
              data-background-suppress
              class="hidden w-[16.9rem] shrink-0 border-r border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--sidebar)_94%,var(--background)_6%)] lg:flex"
            >
              <div class="flex min-h-full w-full flex-col px-7 py-6">
                <.link navigate={~p"/"} class="flex items-center gap-3 text-[color:var(--foreground)]">
                  <div class="flex h-12 w-12 items-center justify-center rounded-[0.95rem] bg-[color:var(--brand-ink)] shadow-[0_16px_30px_-26px_color-mix(in_oklch,var(--brand-ink)_70%,transparent)]">
                    <img
                      src={~p"/images/regents-logo.png"}
                      alt="Regents"
                      class="h-8 w-8 rounded-[0.7rem] object-cover"
                    />
                  </div>
                  <div>
                    <p class="font-display text-[2rem] leading-none tracking-[-0.06em]">Regents</p>
                  </div>
                </.link>

                <section class="mt-10">
                  <p class="font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                    {@shell_title}
                  </p>
                  <p class="mt-4 max-w-[14rem] text-[1.02rem] leading-8 text-[color:var(--muted-foreground)]">
                    {sidebar_intro(@shell_eyebrow, @shell_title)}
                  </p>
                </section>

                <nav class="mt-10 space-y-1.5" aria-label="Primary">
                  <%= for item <- @nav_items do %>
                    <%= if item.kind == :internal do %>
                      <.nav_link
                        current={@active_nav == item.key}
                        href={item.href}
                        label={item.label}
                        note={item.note}
                        icon={item.icon}
                      />
                    <% else %>
                      <.external_nav_link href={item.href} label={item.label} note={item.note} />
                    <% end %>
                  <% end %>
                </nav>

                <section class="mt-8 rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_86%,var(--card)_14%)] px-4 py-4">
                  <p class="text-[0.74rem] leading-6 text-[color:var(--muted-foreground)]">
                    Keep access, billing, and launch steps in one guided place.
                  </p>
                  <.app_resume_link
                    current_human={@current_human}
                    class="mt-4 w-full justify-between"
                  />
                </section>

                <div class="mt-auto pt-8">
                  <div class="flex flex-col gap-1.5 text-[0.98rem] text-[color:var(--muted-foreground)]">
                    <.link navigate={~p"/app/dashboard"} class="pp-sidebar-utility-link">
                      Dashboard
                    </.link>
                    <.link navigate={~p"/docs"} class="pp-sidebar-utility-link">
                      Docs
                    </.link>
                    <a
                      href="https://discord.gg/regents"
                      target="_blank"
                      rel="noreferrer"
                      class="pp-sidebar-utility-link"
                    >
                      Community
                    </a>
                    <.link navigate={~p"/bug-report"} class="pp-sidebar-utility-link">
                      Support
                    </.link>
                  </div>

                  <div class="mt-8 flex flex-wrap gap-2.5">
                    <.community_links />
                  </div>
                </div>
              </div>
            </aside>

            <div class="relative flex min-w-0 flex-1 flex-col">
              <div
                id="platform-shell-header-mobile"
                data-background-suppress
                class="relative border-b border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-4 py-4 lg:hidden"
              >
                <div class="space-y-4">
                  <div class="flex items-center justify-between gap-3">
                    <.link
                      navigate={~p"/"}
                      class="flex min-w-0 items-center gap-3 text-[color:var(--foreground)]"
                    >
                      <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-[0.95rem] bg-[color:var(--brand-ink)]">
                        <img
                          src={~p"/images/regents-logo.png"}
                          alt=""
                          class="h-7 w-7 rounded-[0.65rem] object-cover"
                        />
                      </div>
                      <div class="min-w-0">
                        <p class="truncate font-display text-[1.9rem] leading-none tracking-[-0.05em]">
                          Regents
                        </p>
                        <p class="truncate text-[0.82rem] text-[color:var(--muted-foreground)]">
                          {@shell_title}
                        </p>
                      </div>
                    </.link>

                    <div class="flex shrink-0 items-center gap-2">
                      <.theme_toggle_button mode={:mobile} />
                      <.notification_menu current_human={@current_human} mode={:mobile} />
                      <%= if @show_wallet_control do %>
                        <.layout_wallet_control
                          current_human={@current_human}
                          wallet_ready?={@wallet_ready?}
                          config={@wallet_bridge_config}
                          mode={:mobile}
                        />
                      <% end %>
                    </div>
                  </div>

                  <.quick_search_form
                    id_prefix="mobile"
                    items={@quick_search_items}
                    items_json={@quick_search_items_json}
                  />
                </div>
              </div>

              <header
                id="platform-shell-header-desktop"
                data-background-suppress
                class="relative hidden items-center gap-3 border-b border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-4 lg:flex"
              >
                <div class="w-full max-w-[33rem]">
                  <.quick_search_form
                    id_prefix="desktop"
                    items={@quick_search_items}
                    items_json={@quick_search_items_json}
                  />
                </div>

                <div class="ml-auto flex shrink-0 items-center gap-2">
                  <.theme_toggle_button mode={:desktop} />
                  <.notification_menu current_human={@current_human} mode={:desktop} />
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
                class={[
                  "relative min-h-0 flex-1 overflow-y-auto px-4 py-4 sm:px-5 sm:py-5 lg:px-8 lg:py-7",
                  @content_class
                ]}
                tabindex="-1"
              >
                {render_slot(@inner_block)}
              </main>

              <footer
                data-background-suppress
                class="relative space-y-3 border-t border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-5 py-4 text-sm text-[color:var(--muted-foreground)] lg:px-8"
              >
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <p>&copy; Regents Labs 2026</p>
                  <.footer_resource_links />
                </div>
                <.footer_social_links />
              </footer>
            </div>
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

  attr(:current_human, :map, default: nil)
  attr(:wallet_ready?, :boolean, required: true)
  attr(:config, :string, required: true)
  attr(:mode, :atom, default: :desktop)

  defp layout_wallet_control(assigns) do
    ~H"""
    <div
      id={"layout-wallet-control-#{@mode}"}
      phx-update="ignore"
      data-dashboard-config={@config}
      data-wallet-shell
      class={[
        "relative items-center gap-2",
        @mode == :desktop && "hidden lg:flex",
        @mode == :mobile && "flex lg:hidden",
        @mode == :floating && "flex"
      ]}
    >
      <button
        type="button"
        data-wallet-sign-in
        class="inline-flex h-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_48%,var(--border)_52%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_84%,var(--foreground)_16%)] px-4 text-sm text-white/95 shadow-[0_18px_34px_-28px_color-mix(in_oklch,var(--brand-ink)_60%,transparent)] transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_24px_42px_-30px_color-mix(in_oklch,var(--brand-ink)_70%,transparent)] disabled:cursor-not-allowed disabled:opacity-45"
        disabled={!@wallet_ready?}
      >
        Connect wallet
      </button>

      <div data-wallet-connected class="hidden">
        <button
          type="button"
          data-wallet-trigger
          class="inline-flex h-11 items-center gap-3 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 text-sm text-[color:var(--foreground)] shadow-[0_14px_26px_-24px_color-mix(in_oklch,var(--foreground)_16%,transparent)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]"
          aria-expanded="false"
          aria-controls={"layout-wallet-drawer-#{@mode}"}
        >
          <span
            class="inline-flex h-7 w-7 items-center justify-center rounded-[0.7rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--foreground)]"
            aria-hidden="true"
          >
            <.icon name="hero-wallet" class="size-4" />
          </span>
          <span class="max-w-[7.25rem] truncate">
            {connected_wallet_label(@current_human)}
          </span>
          <span
            class="h-2.5 w-2.5 rounded-full bg-[color:var(--brand-ink)] shadow-[0_0_0_4px_color-mix(in_oklch,var(--brand-ink)_16%,transparent)]"
            aria-hidden="true"
          >
          </span>
          <span
            class="text-xs text-[color:var(--muted-foreground)]"
            data-wallet-caret
            aria-hidden="true"
          >
            ↓
          </span>
        </button>

        <div
          id={"layout-wallet-drawer-#{@mode}"}
          data-wallet-drawer
          class="absolute right-0 top-full z-30 mt-3 w-[18rem] rounded-[1.3rem] border border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,var(--card)_4%),color-mix(in_oklch,var(--background)_90%,var(--card)_10%))] p-4 shadow-[0_28px_70px_-46px_color-mix(in_oklch,var(--foreground)_34%,transparent)]"
          hidden
        >
          <div data-wallet-drawer-inner class="space-y-4">
            <div class="space-y-2">
              <p class="text-[0.68rem] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--foreground)_54%,var(--muted-foreground)_46%)]">
                Wallet
              </p>
              <div class="flex items-center gap-2 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] px-3 py-3">
                <span
                  data-wallet-address-text
                  class="min-w-0 flex-1 truncate text-sm text-[color:var(--foreground)]"
                >
                  {abbreviated_wallet(@current_human && @current_human.wallet_address)}
                </span>
                <button
                  type="button"
                  data-wallet-copy
                  class="inline-flex h-9 w-9 items-center justify-center rounded-[0.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
                  aria-label="Copy wallet address"
                  title="Copy full wallet address"
                >
                  <span data-wallet-copy-icon class="inline-flex" aria-hidden="true">
                    <.icon name="hero-document-duplicate" class="size-4" />
                  </span>
                  <span data-wallet-copy-check class="hidden" aria-hidden="true">
                    <.icon name="hero-check" class="size-4" />
                  </span>
                </button>
              </div>
            </div>

            <button
              type="button"
              data-wallet-disconnect
              class="inline-flex w-full items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_86%,var(--card)_14%)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
            >
              Disconnect
            </button>
          </div>
        </div>
      </div>

      <p
        data-dashboard-wallet-notice
        data-notice-style="compact"
        role="status"
        aria-live="polite"
        class="hidden max-w-[18rem] whitespace-pre-line text-sm text-[color:var(--muted-foreground)]"
      >
      </p>
    </div>
    """
  end

  attr(:current_human, :map, default: nil)
  attr(:class, :string, default: nil)

  defp app_resume_link(assigns) do
    assigns =
      assign(assigns, :label, LayoutHelpers.continue_label(assigns.current_human))

    ~H"""
    <.link
      navigate={~p"/app"}
      class={[
        "inline-flex items-center gap-3 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-3 text-sm text-[color:var(--foreground)] shadow-[0_16px_30px_-28px_color-mix(in_oklch,var(--foreground)_16%,transparent)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]",
        @class
      ]}
    >
      <span>{@label}</span>
      <span aria-hidden="true">→</span>
    </.link>
    """
  end

  attr(:href, :string, required: true)
  attr(:label, :string, required: true)
  attr(:note, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:current, :boolean, default: false)

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "group flex items-center gap-3 rounded-[0.95rem] border px-3.5 py-3 transition",
        @current &&
          "border-[color:color-mix(in_oklch,var(--brand-ink)_42%,var(--border)_58%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] text-[color:var(--foreground)] shadow-[0_18px_34px_-30px_color-mix(in_oklch,var(--brand-ink)_34%,transparent)]",
        !@current &&
          "border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--muted-foreground)] hover:border-[color:var(--ring)] hover:text-[color:var(--foreground)]"
      ]}
    >
      <span class={[
        "flex h-10 w-10 shrink-0 items-center justify-center rounded-[0.85rem] border",
        @current &&
          "border-[color:color-mix(in_oklch,var(--brand-ink)_32%,transparent)] bg-[color:color-mix(in_oklch,var(--brand-ink)_16%,var(--background)_84%)] text-[color:var(--brand-ink)]",
        !@current &&
          "border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:color-mix(in_oklch,var(--foreground)_66%,var(--muted-foreground)_34%)]"
      ]}>
        <.icon name={@icon} class="size-5" />
      </span>
      <span class="min-w-0 flex-1">
        <span class="block text-sm text-[color:var(--foreground)]">{@label}</span>
        <span class="mt-1 block text-[0.72rem] uppercase tracking-[0.24em] text-[color:color-mix(in_oklch,var(--foreground)_48%,var(--muted-foreground)_52%)]">
          {@note}
        </span>
      </span>
      <span
        aria-hidden="true"
        class="text-[color:color-mix(in_oklch,var(--foreground)_46%,var(--muted-foreground)_54%)] transition duration-200 group-hover:translate-x-0.5"
      >
        →
      </span>
    </.link>
    """
  end

  attr(:href, :string, required: true)
  attr(:label, :string, required: true)
  attr(:note, :string, default: nil)

  defp external_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      target="_blank"
      rel="noreferrer"
      class="group flex items-center gap-3 rounded-[1.25rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 py-3 text-sm text-[color:var(--muted-foreground)] transition hover:border-[color:var(--ring)] hover:text-[color:var(--foreground)]"
    >
      <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:color-mix(in_oklch,var(--foreground)_66%,var(--muted-foreground)_34%)]">
        <.icon name="hero-arrow-top-right-on-square" class="size-5" />
      </span>
      <span class="min-w-0 flex-1">
        <span class="block text-sm text-[color:var(--foreground)]">{@label}</span>
        <span :if={@note} class="mt-1 block text-[0.72rem] uppercase tracking-[0.24em]">
          {@note}
        </span>
      </span>
      <span aria-hidden="true" class="transition duration-200 group-hover:translate-x-0.5">↗</span>
    </a>
    """
  end

  defp community_links(assigns) do
    ~H"""
    <a
      href="https://x.com/regents_sh"
      target="_blank"
      rel="noreferrer"
      class="inline-flex h-11 w-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
      aria-label="Regents Labs on X"
      title="Regents Labs on X"
    >
      <.x_mark class="size-4" />
    </a>

    <a
      href="https://farcaster.xyz/regent"
      target="_blank"
      rel="noreferrer"
      class="inline-flex h-11 w-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
      aria-label="Regent on Farcaster"
      title="Regent on Farcaster"
    >
      <img src={~p"/images/farcastericon.png"} alt="" class="h-4 w-4 object-contain" />
    </a>

    <a
      href="https://discord.gg/regents"
      target="_blank"
      rel="noreferrer"
      class="inline-flex h-11 w-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
      aria-label="Regents on Discord"
      title="Regents on Discord"
    >
      <.discord_mark class="size-5" />
    </a>

    <a
      href="https://github.com/orgs/regents-ai/repositories"
      target="_blank"
      rel="noreferrer"
      class="inline-flex h-11 w-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
      aria-label="Regents Labs GitHub"
      title="Regents Labs GitHub"
    >
      <.github_mark class="size-5" />
    </a>
    """
  end

  def footer_social_links(assigns) do
    ~H"""
    <div class="pp-home-footer-links" aria-label="Regents Labs footer social links">
      <button
        id="platform-footer-voxel-classic"
        type="button"
        class="pp-home-footer-link pp-footer-voxel-toggle"
        phx-hook="FooterVoxel"
        data-color-mode-cycle
        data-background-suppress
        aria-label="Toggle light and dark mode"
        aria-pressed="false"
        title="Toggle light and dark mode"
      >
        <span class="pp-footer-voxel-scene" data-footer-voxel-scene aria-hidden="true"></span>
      </button>

      <a
        href="https://x.com/regents_sh"
        target="_blank"
        rel="noreferrer"
        class="pp-home-footer-link"
        data-background-suppress
        aria-label="Regents Labs on X"
        title="Regents Labs on X"
      >
        <.x_mark class="pp-social-mark" />
      </a>

      <a
        href="https://farcaster.xyz/regent"
        target="_blank"
        rel="noreferrer"
        class="pp-home-footer-link"
        data-background-suppress
        aria-label="Regent on Farcaster"
        title="Regent on Farcaster"
      >
        <img src={~p"/images/farcastericon.png"} alt="" class="pp-home-footer-icon-image" />
      </a>

      <a
        href="https://discord.gg/regents"
        target="_blank"
        rel="noreferrer"
        class="pp-home-footer-link"
        data-background-suppress
        aria-label="Regents on Discord"
        title="Regents on Discord"
      >
        <.discord_mark class="pp-social-mark" />
      </a>

      <a
        href="https://github.com/orgs/regents-ai/repositories"
        target="_blank"
        rel="noreferrer"
        class="pp-home-footer-link"
        data-background-suppress
        aria-label="Regents Labs GitHub"
        title="Regents Labs GitHub"
      >
        <.github_mark class="size-5" />
      </a>

      <a
        href="https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"
        target="_blank"
        rel="noreferrer"
        class="pp-home-footer-link"
        data-background-suppress
        aria-label="View $REGENT on GeckoTerminal"
        title="View $REGENT on GeckoTerminal"
      >
        <img src={~p"/images/geckoterminallogo.png"} alt="" class="pp-home-footer-icon-image" />
      </a>
    </div>
    """
  end

  def footer_resource_links(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
      <.link navigate={~p"/docs"} class="hover:text-[color:var(--foreground)]">
        Docs
      </.link>
      <.link navigate={~p"/token-info"} class="hover:text-[color:var(--foreground)]">
        Token info
      </.link>
      <.link navigate={~p"/bug-report"} class="hover:text-[color:var(--foreground)]">
        Bug report
      </.link>
      <a
        href="https://news.regents.sh"
        target="_blank"
        rel="noreferrer"
        class="hover:text-[color:var(--foreground)]"
      >
        News
      </a>
    </div>
    """
  end

  attr(:items, :list, required: true)
  attr(:items_json, :string, required: true)
  attr(:id_prefix, :string, required: true)

  defp quick_search_form(assigns) do
    ~H"""
    <form
      id={"layout-quick-search-#{@id_prefix}"}
      class="group flex h-11 items-center gap-3 overflow-hidden rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-3 shadow-[inset_0_1px_0_color-mix(in_oklch,var(--background)_18%,transparent)] transition duration-200 focus-within:border-[color:var(--ring)] focus-within:shadow-[0_0_0_1px_color-mix(in_oklch,var(--ring)_55%,transparent)]"
      phx-hook="QuickSearch"
      data-search-items={@items_json}
      data-search-default={~p"/docs"}
    >
      <label class="sr-only" for={"layout-quick-search-input-#{@id_prefix}"}>
        Search pages and actions
      </label>
      <span
        class="flex h-8 w-8 shrink-0 items-center justify-center rounded-[0.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:color-mix(in_oklch,var(--foreground)_56%,var(--muted-foreground)_44%)]"
        aria-hidden="true"
      >
        <.icon name="hero-magnifying-glass" class="size-4" />
      </span>
      <input
        id={"layout-quick-search-input-#{@id_prefix}"}
        class="min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-[color:var(--foreground)] outline-none placeholder:text-[color:color-mix(in_oklch,var(--foreground)_44%,var(--muted-foreground)_56%)] focus:ring-0"
        type="search"
        name="search"
        list={"layout-quick-search-suggestions-#{@id_prefix}"}
        placeholder="Search setup, docs, and pages"
        autocomplete="off"
      />
      <datalist id={"layout-quick-search-suggestions-#{@id_prefix}"}>
        <option :for={item <- @items} value={item.label} />
      </datalist>
      <button
        type="submit"
        class="inline-flex h-8 shrink-0 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-3 text-[0.68rem] uppercase tracking-[0.24em] text-[color:color-mix(in_oklch,var(--foreground)_58%,var(--muted-foreground)_42%)] transition duration-200 hover:border-[color:var(--ring)] hover:text-[color:var(--foreground)]"
      >
        Find
      </button>
    </form>
    """
  end

  attr(:mode, :atom, default: :desktop)

  defp theme_toggle_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "inline-flex h-11 w-11 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]",
        @mode == :mobile && "h-10 w-10 rounded-[0.95rem]"
      ]}
      data-color-mode-cycle
      aria-label="Toggle light and dark mode"
      title="Toggle light and dark mode"
    >
      <span class="inline-flex" aria-hidden="true">
        <.icon name="hero-sun" class="size-4" />
      </span>
      <span class="hidden" aria-hidden="true">
        <.icon name="hero-moon" class="size-4" />
      </span>
    </button>
    """
  end

  attr(:current_human, :map, default: nil)
  attr(:mode, :atom, default: :desktop)

  defp notification_menu(assigns) do
    assigns =
      assign(assigns, :next_label, LayoutHelpers.continue_label(assigns.current_human))

    ~H"""
    <details class="relative">
      <summary
        class={[
          "list-none inline-flex h-11 w-11 items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]",
          @mode == :mobile && "h-10 w-10 rounded-[0.95rem]"
        ]}
        aria-label="Open alerts and quick links"
        title="Alerts and quick links"
      >
        <span
          class="absolute right-3 top-3 h-2 w-2 rounded-full bg-[color:var(--brand-ink)]"
          aria-hidden="true"
        >
        </span>
        <.icon name="hero-bell" class="size-4" />
      </summary>
      <div class="absolute right-0 top-full z-30 mt-3 w-[16rem] rounded-[1.25rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,var(--card)_4%),color-mix(in_oklch,var(--background)_90%,var(--card)_10%))] p-4 shadow-[0_28px_70px_-46px_color-mix(in_oklch,var(--foreground)_34%,transparent)]">
        <p class="text-[0.68rem] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--foreground)_54%,var(--muted-foreground)_46%)]">
          Quick links
        </p>
        <div class="mt-3 space-y-2">
          <.link
            navigate={~p"/app"}
            class="flex items-center justify-between rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-3 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
          >
            {@next_label}
            <span aria-hidden="true">→</span>
          </.link>
          <.link
            navigate={~p"/docs"}
            class="flex items-center justify-between rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-3 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
          >
            Docs <span aria-hidden="true">→</span>
          </.link>
          <.link
            navigate={~p"/bug-report"}
            class="flex items-center justify-between rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-3 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
          >
            Bug report <span aria-hidden="true">→</span>
          </.link>
        </div>
      </div>
    </details>
    """
  end

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

  defp connected_wallet_label(nil), do: "Wallet"

  defp connected_wallet_label(%{wallet_address: wallet_address}) when is_binary(wallet_address) do
    case abbreviated_wallet(wallet_address) do
      "" -> "Wallet"
      shortened -> shortened
    end
  end

  defp connected_wallet_label(_current_human), do: "Wallet"

  defp sidebar_intro("App setup", _shell_title),
    do: "Complete each step to open your agent company."

  defp sidebar_intro("Agent trust", _shell_title),
    do: "Review trust, confirm identity, and keep the approval private."

  defp sidebar_intro("Public company", _shell_title),
    do: "Track what this company offers, what it has shipped, and how people can reach it."

  defp sidebar_intro(_shell_eyebrow, _shell_title),
    do: "Use this page to move work forward without leaving the main workspace."

  attr(:class, :string, default: nil)

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

  attr(:class, :string, default: nil)

  defp github_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class={@class}>
      <path d="M12 2C6.48 2 2 6.58 2 12.22c0 4.5 2.87 8.31 6.84 9.66.5.1.68-.22.68-.49 0-.24-.01-1.05-.01-1.91-2.78.62-3.37-1.21-3.37-1.21-.45-1.19-1.11-1.5-1.11-1.5-.91-.64.07-.63.07-.63 1 .08 1.53 1.06 1.53 1.06.9 1.56 2.35 1.11 2.92.85.09-.67.35-1.11.63-1.37-2.22-.26-4.56-1.14-4.56-5.08 0-1.12.39-2.04 1.03-2.76-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05A9.35 9.35 0 0 1 12 6.84c.85 0 1.71.12 2.51.35 1.91-1.33 2.75-1.05 2.75-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.64 1.03 2.76 0 3.95-2.34 4.81-4.58 5.07.36.32.68.95.68 1.91 0 1.38-.01 2.49-.01 2.83 0 .27.18.59.69.49A10.24 10.24 0 0 0 22 12.22C22 6.58 17.52 2 12 2Z" />
    </svg>
    """
  end

  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
