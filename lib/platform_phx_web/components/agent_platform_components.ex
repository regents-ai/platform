defmodule PlatformPhxWeb.AgentPlatformComponents do
  @moduledoc false
  use Phoenix.Component

  use Regent

  import PlatformPhxWeb.PlatformComponents, only: [preview_link: 1]

  attr :agent, :map, required: true
  attr :preview_path, :string, default: nil

  def agent_market_card(assigns) do
    ~H"""
    <article
      data-platform-card
      class="pp-route-panel pp-product-panel flex h-full flex-col gap-5 overflow-hidden"
    >
      <div class="space-y-3">
        <p class="pp-home-kicker">Built-in Example</p>
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div class="space-y-2">
            <h2 class="pp-route-panel-title">{@agent.name}</h2>
            <p class="pp-panel-copy">{@agent.public_summary}</p>
          </div>
          <div class="rounded-full border border-[color:var(--border)] bg-[color:var(--card)] px-3 py-1 text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
            {@agent.subdomain && @agent.subdomain.hostname}
          </div>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
          <p class="pp-home-kicker">Services</p>
          <div class="mt-3 space-y-3">
            <%= for service <- Enum.take(@agent.services || [], 2) do %>
              <div class="space-y-1">
                <div class="flex items-center justify-between gap-3">
                  <p class="font-display text-[1rem] leading-none">{service.name}</p>
                  <span class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                    {service.payment_rail}
                  </span>
                </div>
                <p class="text-sm text-[color:var(--muted-foreground)]">{service.summary}</p>
                <p class="text-sm text-[color:var(--foreground)]">{service.price_label}</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
          <p class="pp-home-kicker">Operator Rails</p>
          <div class="mt-3 grid gap-2">
            <div class="flex items-center justify-between gap-3 rounded-xl border border-[color:var(--border)] px-3 py-2 text-sm">
              <span>Sprite + Paperclip</span>
              <span class="text-[color:var(--muted-foreground)]">Regents-managed</span>
            </div>
            <%= for connection <- @agent.connections || [] do %>
              <div class="flex items-center justify-between gap-3 rounded-xl border border-[color:var(--border)] px-3 py-2 text-sm">
                <span class="capitalize">{connection.kind}</span>
                <span class="text-[color:var(--muted-foreground)]">{connection.status}</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="mt-auto flex flex-wrap gap-3">
        <.preview_link
          :if={@agent.subdomain && @agent.subdomain.active}
          variant="pill"
          href={"https://#{@agent.subdomain.hostname}"}
        >
          Open public page <span aria-hidden="true">↗</span>
        </.preview_link>
        <.link
          :if={@preview_path}
          navigate={@preview_path}
          class="pp-link-button pp-link-button-ghost pp-link-button-slim"
        >
          Open preview <span aria-hidden="true">→</span>
        </.link>
      </div>
    </article>
    """
  end

  attr :agent, :map, required: true
  attr :owner_company, :map, default: nil
  attr :billing_account, :map, default: nil
  attr :launch_home_path, :string, default: nil

  def public_agent_page(assigns) do
    ~H"""
    <div class="mx-auto flex max-w-[1240px] flex-col gap-6">
      <section class="pp-route-panel pp-product-panel pp-product-panel--feature overflow-hidden">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(18rem,0.8fr)]">
          <div class="space-y-5">
            <div class="space-y-3">
              <p class="pp-home-kicker">Regent company</p>
              <div class="flex flex-wrap items-center gap-3">
                <h1 class="font-display text-[clamp(2.5rem,5vw,4.8rem)] leading-[0.9]">
                  {@agent.name}
                </h1>
                <span class="rounded-full border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-2 text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  {@agent.subdomain && @agent.subdomain.hostname}
                </span>
              </div>
              <p class="max-w-[58ch] text-base leading-7 text-[color:var(--muted-foreground)]">
                {@agent.hero_statement || @agent.public_summary}
              </p>
            </div>

            <div class="flex flex-wrap gap-3">
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-3">
                <p class="pp-home-kicker">Claimed Name</p>
                <p class="mt-2 text-sm">{@agent.basename_fqdn}</p>
              </div>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-3">
                <p class="pp-home-kicker">Public identity</p>
                <p class="mt-2 text-sm">{@agent.ens_fqdn}</p>
              </div>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-3">
                <p class="pp-home-kicker">How this company works</p>
                <p class="mt-2 max-w-[28ch] text-sm text-[color:var(--muted-foreground)]">
                  This page is the public home for the company. Owners can manage it here after signing in.
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:var(--card)] p-5">
            <p class="pp-home-kicker">Company profile</p>
            <div class="mt-4 grid gap-3">
              <div class="rounded-xl border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <div>
                  <p class="font-display text-[1rem] leading-none">Public company home</p>
                  <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                    Visitors can learn what this company offers and see the public work it shares here.
                  </p>
                </div>
              </div>
              <%= for connection <- @agent.connections || [] do %>
                <div class="flex items-center justify-between gap-3 rounded-xl border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                  <div>
                    <p class="font-display text-[1rem] leading-none capitalize">{connection.kind}</p>
                    <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                      {connection.display_name}
                    </p>
                  </div>
                  <span class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                    {connection.status}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </section>

      <section
        :if={@owner_company}
        id="agent-owner-controls"
        class="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_minmax(18rem,0.85fr)]"
      >
        <article class="pp-route-panel pp-product-panel space-y-4">
          <div class="space-y-2">
            <p class="pp-home-kicker">Owner controls</p>
            <h2 class="pp-route-panel-title">Manage your company from here</h2>
            <p class="pp-panel-copy max-w-[42rem]">
              Only you can see this section. Pause the company, turn it back on, or jump back to the launch home.
            </p>
          </div>

          <div class="grid gap-4 sm:grid-cols-3">
            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
              <p class="pp-home-kicker">Company status</p>
              <p class="mt-3 font-display text-[1.15rem] text-[color:var(--foreground)]">
                {owner_status_label(@owner_company)}
              </p>
              <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                {owner_status_copy(@owner_company)}
              </p>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
              <p class="pp-home-kicker">Runtime balance</p>
              <p class="mt-3 font-display text-[1.15rem] text-[color:var(--foreground)]">
                {billing_balance(@billing_account)}
              </p>
              <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                Add funds before this reaches zero to avoid a pause.
              </p>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
              <p class="pp-home-kicker">Public address</p>
              <p class="mt-3 font-display text-[1.15rem] text-[color:var(--foreground)]">
                {@agent.subdomain && @agent.subdomain.hostname}
              </p>
              <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                This is the company home visitors can open.
              </p>
            </div>
          </div>

          <div class="flex flex-wrap gap-3">
            <button
              :if={owner_company_paused?(@owner_company)}
              id="agent-owner-resume"
              type="button"
              phx-click="resume_company"
              phx-value-slug={@owner_company.slug}
              class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
            >
              Resume company
            </button>

            <button
              :if={!owner_company_paused?(@owner_company)}
              id="agent-owner-pause"
              type="button"
              phx-click="pause_company"
              phx-value-slug={@owner_company.slug}
              class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
            >
              Pause company
            </button>

            <.link
              :if={@launch_home_path}
              navigate={@launch_home_path}
              class="pp-link-button pp-link-button-ghost pp-link-button-slim"
            >
              Open launch home
            </.link>
          </div>
        </article>

        <article class="pp-route-panel pp-product-panel space-y-4">
          <div class="space-y-2">
            <p class="pp-home-kicker">Owner note</p>
            <h2 class="pp-route-panel-title">What pause does</h2>
          </div>

          <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
            <p class="text-sm leading-7 text-[color:var(--muted-foreground)]">
              Pausing stops new work from running, keeps your company page online, and keeps your progress saved. Turn it back on whenever you are ready.
            </p>
          </div>
        </article>
      </section>

      <section class="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_minmax(18rem,0.85fr)]">
        <article class="pp-route-panel pp-product-panel space-y-4">
          <div class="space-y-2">
            <p class="pp-home-kicker">Service menu</p>
            <h2 class="pp-route-panel-title">Ways to work with this company</h2>
          </div>

          <div class="grid gap-4">
            <%= for service <- @agent.services || [] do %>
              <section class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div class="space-y-1">
                    <h3 class="font-display text-[1.15rem] leading-none">{service.name}</h3>
                    <p class="text-sm text-[color:var(--muted-foreground)]">{service.summary}</p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm text-[color:var(--foreground)]">{service.price_label}</p>
                    <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                      {service.payment_rail}
                    </p>
                  </div>
                </div>
              </section>
            <% end %>
          </div>
        </article>

        <article class="pp-route-panel pp-product-panel space-y-4">
          <div class="space-y-2">
            <p class="pp-home-kicker">Public work feed</p>
            <h2 class="pp-route-panel-title">Recent finished work</h2>
          </div>

          <div class="grid gap-4">
            <%= for artifact <- @agent.feed || [] do %>
              <section class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                <div class="space-y-2">
                  <div class="flex flex-wrap items-center justify-between gap-3">
                    <h3 class="font-display text-[1.1rem] leading-none">{artifact.title}</h3>
                    <span class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                      {artifact.published_at}
                    </span>
                  </div>
                  <p class="text-sm text-[color:var(--muted-foreground)]">{artifact.summary}</p>
                  <a
                    :if={artifact.url}
                    href={artifact.url}
                    target="_blank"
                    rel="noreferrer"
                    class="inline-flex items-center gap-2 text-sm text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4"
                  >
                    Open public page <span aria-hidden="true">↗</span>
                  </a>
                </div>
              </section>
            <% end %>
          </div>
        </article>
      </section>
    </div>
    """
  end

  defp owner_company_paused?(company) do
    company.desired_runtime_state == "paused" or company.runtime_status == "paused"
  end

  defp owner_status_label(company) do
    if owner_company_paused?(company), do: "Paused", else: "Running"
  end

  defp owner_status_copy(company) do
    if owner_company_paused?(company) do
      "Visitors can still view the company page. New work waits until you resume."
    else
      "The company is ready to take new work."
    end
  end

  defp billing_balance(%{runtime_credit_balance_usd_cents: cents}) when is_integer(cents) do
    "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp billing_balance(_billing_account), do: "$0.00"
end
