defmodule PlatformPhxWeb.AppComponents do
  use PlatformPhxWeb, :html

  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhxWeb.TokenCardPayload

  attr :command, :string, required: true
  attr :label, :string, default: "Copy install command"
  attr :id, :string, default: "home-command-copy"

  def home_command(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] p-3 shadow-[0_20px_50px_-42px_color-mix(in_oklch,var(--brand-ink)_45%,transparent)] sm:flex-row sm:items-center sm:justify-between">
      <code class="overflow-x-auto rounded-[1rem] bg-[color:color-mix(in_oklch,var(--card)_84%,var(--background)_16%)] px-4 py-3 text-sm text-[color:var(--foreground)]">
        {@command}
      </code>
      <button
        id={@id}
        type="button"
        phx-hook="ClipboardCopy"
        data-copy-text={@command}
        class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
        aria-label={@label}
      >
        {@label}
      </button>
    </div>
    """
  end

  def journey_steps(assigns) do
    assigns =
      assign(assigns, :steps, [
        %{
          number: "1",
          title: "Form",
          copy: "Claim your name, add billing, and open the company."
        },
        %{
          number: "2",
          title: "Improve",
          copy: "Bring the agent into Techtree for research, publishing, and collaboration."
        },
        %{
          number: "3",
          title: "Fund",
          copy: "Move into Autolaunch when you are ready to raise and grow."
        }
      ])

    ~H"""
    <div class="grid gap-4 md:grid-cols-3">
      <%= for step <- @steps do %>
        <section class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] p-5">
          <p class="text-[10px] uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
            Step {step.number}
          </p>
          <h3 class="mt-3 font-display text-2xl text-[color:var(--foreground)]">{step.title}</h3>
          <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">{step.copy}</p>
        </section>
      <% end %>
    </div>
    """
  end

  def home_capability_grid(assigns) do
    assigns =
      assign(assigns, :items, [
        %{
          title: "Regent identity",
          copy: "Keep one claimed name tied to the company you are building."
        },
        %{
          title: "Hosted company",
          copy: "Open the company in one guided flow and come back to control it later."
        },
        %{
          title: "Local CLI",
          copy: "Install the local tool when the work moves onto a machine or into an agent."
        },
        %{
          title: "Next surfaces",
          copy: "Step into Techtree to improve the agent and Autolaunch when funding is next."
        }
      ])

    ~H"""
    <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <%= for item <- @items do %>
        <article class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:var(--card)] p-5">
          <h3 class="font-display text-xl text-[color:var(--foreground)]">{item.title}</h3>
          <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">{item.copy}</p>
        </article>
      <% end %>
    </div>
    """
  end

  def sister_project_cards(assigns) do
    assigns =
      assign(assigns, :projects, [
        %{
          title: "Techtree",
          href: "/techtree",
          kicker: "Improve the agent",
          copy:
            "Open the research, publishing, and collaboration lane after the company is ready."
        },
        %{
          title: "Autolaunch",
          href: "/autolaunch",
          kicker: "Fund the agent",
          copy:
            "Use the funding lane when launch planning, capital, and post-launch tracking come next."
        }
      ])

    ~H"""
    <div class="grid gap-4 lg:grid-cols-2">
      <%= for project <- @projects do %>
        <section class="rounded-[1.8rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_94%,var(--background)_6%),color-mix(in_oklch,var(--background)_88%,var(--card)_12%))] p-6 shadow-[0_24px_70px_-48px_color-mix(in_oklch,var(--brand-ink)_45%,transparent)]">
          <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
            {project.kicker}
          </p>
          <h3 class="mt-3 font-display text-[clamp(2rem,4vw,2.6rem)] leading-[0.95] text-[color:var(--foreground)]">
            {project.title}
          </h3>
          <p class="mt-4 max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
            {project.copy}
          </p>
          <div class="mt-6">
            <.link
              navigate={project.href}
              class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
            >
              Open {project.title} <span aria-hidden="true">→</span>
            </.link>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  attr :services, :map, required: true
  attr :redeem_island_config, :string, required: true

  def access_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_services(assigns.services))
      |> assign(:facts, [
        %{
          icon: "hero-wallet",
          title: "Wallet check",
          copy: "Confirm the wallet session before anything else can move."
        },
        %{
          icon: "hero-shield-check",
          title: "Pass access",
          copy: "A qualifying pass unlocks the company setup path."
        },
        %{
          icon: "hero-arrow-right-circle",
          title: "Identity next",
          copy: "As soon as access is ready, you move straight to the company name."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: 2,
          title: "Claim identity",
          copy: "Choose the company name you want to carry into launch."
        },
        %{
          number: 3,
          title: "Add billing",
          copy: "Turn payments on so the hosted company can go live."
        },
        %{
          number: 4,
          title: "Open company",
          copy: "We launch the company and prepare its live page."
        }
      ])

    ~H"""
    <.setup_flow_frame
      step={1}
      title="Check access"
      summary="Check whether this wallet can open a company. Start by confirming wallet access and pass eligibility. If this wallet still needs access, you can redeem it here without leaving the setup flow."
      snapshot={@snapshot}
      facts={@facts}
      next_steps={@next_steps}
    >
      <div class="grid gap-5 xl:grid-cols-[minmax(0,1.18fr)_minmax(18rem,0.82fr)]">
        <section
          id="app-access-redeem"
          phx-hook="DashboardRedeem"
          data-dashboard-config={@redeem_island_config}
          class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_12%,var(--border)_88%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,var(--card)_4%),color-mix(in_oklch,var(--card)_88%,var(--background)_12%))] p-5 shadow-[0_24px_60px_-46px_color-mix(in_oklch,var(--brand-ink)_22%,transparent)] sm:p-6"
        >
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="space-y-2">
              <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Redeem a pass
              </p>
              <h3 class="font-display text-[clamp(1.8rem,2.8vw,2.3rem)] leading-[0.92] text-[color:var(--foreground)]">
                Turn an eligible pass into company access.
              </h3>
              <p class="max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                Use this when the wallet holds a qualifying collection item but has not unlocked company setup yet.
              </p>
            </div>

            <a
              href="https://opensea.io/collection/regents-club"
              target="_blank"
              rel="noreferrer"
              class="inline-flex items-center gap-2 rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
            >
              <.opensea_mark />
              <span>OpenSea</span>
            </a>
          </div>

          <%= if @services.holdings_notice do %>
            <.inline_notice notice={@services.holdings_notice} class="mt-5" />
          <% end %>

          <div class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <.metric_tile
              label="Collection I"
              value={Integer.to_string(length(@services.holdings.animata1))}
              copy="Eligible tokens in this wallet."
            />
            <.metric_tile
              label="Collection II"
              value={Integer.to_string(length(@services.holdings.animata2))}
              copy="Eligible tokens in this wallet."
            />
            <.metric_tile
              label="Regents Club"
              value={Integer.to_string(length(@services.holdings.animata_pass))}
              copy="Passes already held here."
            />
            <.metric_tile
              label="Snapshot claims"
              value={Integer.to_string(allowance_remaining(@services))}
              copy="Unused name claims still available."
            />
          </div>

          <div class="mt-5 rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4 sm:p-5">
            <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
              <label class="space-y-2">
                <span class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Source collection
                </span>
                <select
                  data-dashboard-redeem-source
                  class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
                >
                  <option value="ANIMATA1">Animata I</option>
                  <option value="ANIMATA2">Animata II</option>
                </select>
              </label>

              <label class="space-y-2">
                <span class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Token ID
                </span>
                <input
                  data-dashboard-redeem-token-id
                  type="text"
                  inputmode="numeric"
                  placeholder="123"
                  class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
                />
              </label>
            </div>

            <div class="mt-4 flex flex-wrap gap-3">
              <button
                type="button"
                data-dashboard-redeem-approve-nft
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Approve NFT
              </button>
              <button
                type="button"
                data-dashboard-redeem-approve-usdc
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Approve payment
              </button>
              <button
                type="button"
                data-dashboard-redeem-start
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white shadow-[0_18px_30px_-24px_color-mix(in_oklch,var(--brand-ink)_85%,transparent)] transition hover:brightness-110"
              >
                Redeem access
              </button>
              <button
                type="button"
                data-dashboard-redeem-claim
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Claim unlocked pass
              </button>
            </div>

            <p data-dashboard-redeem-notice class="mt-4 hidden text-sm leading-6"></p>
          </div>
        </section>

        <div class="space-y-4">
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
            <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
              Ready for the next step
            </p>
            <div class="mt-4 space-y-3">
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Wallet
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  {if @snapshot.wallet_connected?,
                    do: "Signed in and ready to continue.",
                    else: "Sign in so Regents can read this wallet and continue setup."}
                </p>
              </div>
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Pass access
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  {if @snapshot.pass_ready?,
                    do: "This wallet already qualifies for company setup.",
                    else: "Redeem or acquire a qualifying pass before moving into the company name."}
                </p>
              </div>
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Current blocker
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  {access_blocker_copy(@services)}
                </p>
              </div>
            </div>
          </section>

          <.setup_callout
            title="Identity comes next"
            copy="Once access is clear, you will claim or choose the company name that appears on Regents and on the public company page."
          >
            <%= if @snapshot.wallet_connected? and @snapshot.pass_ready? do %>
              <.link
                navigate={~p"/app/identity"}
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
              >
                Continue to identity
              </.link>
            <% else %>
              <a
                href="https://opensea.io/collection/regents-club"
                target="_blank"
                rel="noreferrer"
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Find a qualifying pass
              </a>
            <% end %>
          </.setup_callout>
        </div>
      </div>
    </.setup_flow_frame>
    """
  end

  attr :services, :map, required: true
  attr :phase1_form, :map, required: true
  attr :phase2_form, :map, required: true
  attr :phase1_state, :map, required: true
  attr :phase2_state, :map, required: true
  attr :claim_island_config, :string, required: true
  attr :wallet_ready?, :boolean, required: true

  def identity_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_services(assigns.services))
      |> assign(:facts, [
        %{
          icon: "hero-finger-print",
          title: "Unique identity",
          copy: "Your chosen name becomes the company identity across Regents."
        },
        %{
          icon: "hero-globe-alt",
          title: "Public company page",
          copy: "The same name becomes the live address on regents.sh."
        },
        %{
          icon: "hero-bookmark-square",
          title: "One-time claim",
          copy: "Once a name is used, it stays tied to the company you open."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: 3,
          title: "Add billing",
          copy: "Activate payments so the hosted company can be opened."
        },
        %{
          number: 4,
          title: "Open company",
          copy: "Launch the company and prepare the public page."
        }
      ])

    ~H"""
    <section
      id="app-identity-shell"
      phx-hook="DashboardNameClaim"
      data-dashboard-config={@claim_island_config}
    >
      <.setup_flow_frame
        step={2}
        title="Claim identity"
        summary="Choose a name that will represent the company on Regents. You can use a ready name from this wallet or claim a new one right here."
        snapshot={@snapshot}
        facts={@facts}
        next_steps={@next_steps}
      >
        <%= if @services.allowance_notice do %>
          <.inline_notice notice={@services.allowance_notice} class="mb-5" />
        <% end %>

        <div class="space-y-5">
          <div class="grid gap-4 lg:grid-cols-2">
            <section class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-4">
              <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                Current blocker
              </p>
              <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
                {identity_blocker_copy(@wallet_ready?)}
              </p>
            </section>

            <section class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-4">
              <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                What you can do now
              </p>
              <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
                Use a ready name from this wallet or claim a new one below. Once a name is ready, billing is next.
              </p>
            </section>
          </div>

          <section class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_12%,var(--border)_88%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--card)_90%,var(--background)_10%))] p-5 shadow-[0_24px_60px_-48px_color-mix(in_oklch,var(--brand-ink)_22%,transparent)] sm:p-6">
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div class="space-y-2">
                <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                  Choose a ready name
                </p>
                <h3 class="font-display text-[clamp(1.8rem,2.8vw,2.3rem)] leading-[0.92] text-[color:var(--foreground)]">
                  Use a claimed name or pick a new one.
                </h3>
                <p class="max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Ready names can move straight into billing. New names can be claimed below when the wallet is ready.
                </p>
              </div>

              <div class="rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] px-4 py-2 text-sm text-[color:var(--foreground)]">
                {available_claim_count(@services)} ready
              </div>
            </div>

            <div class="mt-5 space-y-3">
              <%= if @services.available_claims == [] do %>
                <div class="rounded-[1.2rem] border border-dashed border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] px-4 py-5 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  No ready names yet. Claim a new one below and it will appear here as soon as it is available for company setup.
                </div>
              <% else %>
                <%= for claim <- @services.available_claims do %>
                  <div class="grid gap-3 rounded-[1.25rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] px-4 py-4 sm:grid-cols-[minmax(0,1fr)_auto_auto] sm:items-center">
                    <div>
                      <p class="font-display text-[1.2rem] text-[color:var(--foreground)]">
                        {claim.ens_fqdn || "#{claim.label}.regent.eth"}
                      </p>
                      <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                        Public page: {claim.label}.regents.sh
                      </p>
                    </div>

                    <span class="inline-flex items-center justify-center rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] bg-[color:color-mix(in_oklch,var(--positive)_10%,transparent)] px-3 py-1 text-xs uppercase tracking-[0.18em] text-[color:var(--foreground)]">
                      Ready
                    </span>

                    <.link
                      navigate={~p"/app/billing?claimedLabel=#{claim.label}"}
                      class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                    >
                      Use this name
                    </.link>
                  </div>
                <% end %>
              <% end %>
            </div>
          </section>

          <div class="grid gap-5 xl:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
            <section class="space-y-4 rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
              <div>
                <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Claimed names on this wallet
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Names that are already on this wallet stay visible here so you can see which ones are still free for a new company.
                </p>
              </div>

              <div class="space-y-3">
                <%= if @services.owned_names == [] do %>
                  <div class="rounded-[1.1rem] border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                    No claimed names yet.
                  </div>
                <% else %>
                  <%= for name <- @services.owned_names do %>
                    <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                      <div class="flex flex-wrap items-center justify-between gap-3">
                        <div>
                          <p class="font-display text-[1.05rem] text-[color:var(--foreground)]">
                            {name.ens_fqdn || name.fqdn}
                          </p>
                          <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                            {if name.is_in_use,
                              do: "Already used by a company.",
                              else: "Still available for a new company."}
                          </p>
                        </div>

                        <span class={name_claim_badge_class(name.is_in_use)}>
                          {if name.is_in_use, do: "In use", else: "Held by you"}
                        </span>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Recent claims
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <%= if @services.recent_names == [] do %>
                    <span class="text-sm text-[color:var(--muted-foreground)]">
                      No recent names yet.
                    </span>
                  <% else %>
                    <%= for name <- @services.recent_names do %>
                      <span class="rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-1.5 text-sm text-[color:var(--foreground)]">
                        {name.label}.{ens_parent_name(@services)}
                      </span>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </section>

            <section class="grid gap-4 xl:grid-cols-2">
              <.form
                for={@phase1_form}
                id="app-identity-snapshot-form"
                phx-change="change_phase1_label"
                class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5"
              >
                <div class="space-y-4">
                  <div>
                    <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                      Snapshot claim
                    </p>
                    <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      Use an available wallet claim when you want to keep the name inside the setup flow.
                    </p>
                  </div>

                  <.input
                    id="app-identity-phase1-name"
                    field={@phase1_form[:label]}
                    type="text"
                    placeholder="Enter a name"
                    autocomplete="off"
                    autocapitalize="none"
                    spellcheck="false"
                    data-1p-ignore="true"
                    data-lpignore="true"
                    class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
                  />

                  <.availability_state state={@phase1_state} />
                  <input
                    type="hidden"
                    id="phase1-normalized-label"
                    value={@phase1_state.normalized_label}
                  />
                  <input type="hidden" id="phase1-fqdn" value={@phase1_state.fqdn || ""} />
                  <input type="hidden" id="phase1-ens-fqdn" value={@phase1_state.ens_fqdn || ""} />

                  <button
                    type="button"
                    data-dashboard-claim-free
                    class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white shadow-[0_18px_30px_-24px_color-mix(in_oklch,var(--brand-ink)_85%,transparent)] transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-55"
                    disabled={!can_free_claim?(@services, @phase1_state, @wallet_ready?)}
                  >
                    Claim from snapshot
                  </button>
                </div>
              </.form>

              <.form
                for={@phase2_form}
                id="app-identity-public-form"
                phx-change="change_phase2_label"
                class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5"
              >
                <div class="space-y-4">
                  <div>
                    <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                      Public claim
                    </p>
                    <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      Use this when you want to pay for a new public name and carry it into billing next.
                    </p>
                  </div>

                  <.input
                    id="app-identity-phase2-name"
                    field={@phase2_form[:label]}
                    type="text"
                    placeholder="Enter a name"
                    autocomplete="off"
                    autocapitalize="none"
                    spellcheck="false"
                    data-1p-ignore="true"
                    data-lpignore="true"
                    class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
                  />

                  <.availability_state state={@phase2_state} />
                  <input
                    type="hidden"
                    id="phase2-normalized-label"
                    value={@phase2_state.normalized_label}
                  />
                  <input type="hidden" id="phase2-fqdn" value={@phase2_state.fqdn || ""} />
                  <input type="hidden" id="phase2-ens-fqdn" value={@phase2_state.ens_fqdn || ""} />

                  <button
                    type="button"
                    data-dashboard-claim-paid
                    data-price-wei={basenames_price_wei(@services)}
                    data-payment-recipient={basenames_payment_recipient(@services)}
                    class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] disabled:cursor-not-allowed disabled:opacity-55"
                    disabled={!can_paid_claim?(@services, @phase2_state, @wallet_ready?)}
                  >
                    Pay and claim
                  </button>
                </div>
              </.form>
            </section>
          </div>

          <.setup_callout
            title="Billing follows identity"
            copy="Once a name is ready, you will choose which one to carry forward and activate billing for the hosted company."
          >
            <%= if available_claim_count(@services) > 0 do %>
              <.link
                navigate={billing_next_ready_path(@services)}
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
              >
                Continue to billing
              </.link>
            <% else %>
              <span class="rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--muted-foreground)]">
                Claim a name to continue
              </span>
            <% end %>
          </.setup_callout>
        </div>

        <p data-dashboard-claim-notice class="hidden text-sm leading-6"></p>
      </.setup_flow_frame>
    </section>
    """
  end

  attr :formation, :map, required: true
  attr :selected_claimed_label, :string, default: nil
  attr :setup_form, :map, required: true
  attr :billing_notice, :map, default: nil

  def billing_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_formation(assigns.formation))
      |> assign(:facts, [
        %{
          icon: "hero-credit-card",
          title: "Usage billing",
          copy: "Activate billing once, then reuse it for hosted company work."
        },
        %{
          icon: "hero-banknotes",
          title: "Stored credit",
          copy: "Any launch credit appears here as soon as it is available."
        },
        %{
          icon: "hero-rocket-launch",
          title: "Launch gate",
          copy: "Company opening stays locked until billing is active."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: 4,
          title: "Open company",
          copy: "Use the chosen name, launch the company, and open the public page."
        }
      ])

    ~H"""
    <.setup_flow_frame
      step={3}
      title="Add billing"
      summary="Choose the claimed name you want to use for launch, then activate billing so Regents can open the hosted company."
      snapshot={@snapshot}
      readiness={Map.get(@formation, :readiness)}
      facts={@facts}
      next_steps={@next_steps}
    >
      <%= if @billing_notice do %>
        <.inline_notice notice={@billing_notice} class="mb-5" />
      <% end %>

      <div class="grid gap-5 xl:grid-cols-[minmax(0,0.98fr)_minmax(18rem,0.82fr)]">
        <section class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_12%,var(--border)_88%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--card)_90%,var(--background)_10%))] p-5 shadow-[0_24px_60px_-48px_color-mix(in_oklch,var(--brand-ink)_22%,transparent)] sm:p-6">
          <.form
            for={@setup_form}
            id="app-billing-form"
            phx-change="change_selected_claim"
            class="space-y-5"
          >
            <div class="space-y-2">
              <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Billing setup
              </p>
              <h3 class="font-display text-[clamp(1.8rem,2.8vw,2.3rem)] leading-[0.92] text-[color:var(--foreground)]">
                Activate billing for the company you are about to open.
              </h3>
              <p class="max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                The selected name becomes the company identity for launch and for the public page.
              </p>
            </div>

            <label class="space-y-2">
              <span class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                Company name
              </span>
              <.input
                field={@setup_form[:claimed_label]}
                type="select"
                options={formation_claim_options(@formation.available_claims)}
                class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
              />
            </label>

            <div class="grid gap-3 sm:grid-cols-2">
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Public company page
                </p>
                <p class="mt-2 font-display text-[1.15rem] text-[color:var(--foreground)]">
                  {selected_hostname(@selected_claimed_label)}
                </p>
              </div>

              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Claimed identity
                </p>
                <p class="mt-2 font-display text-[1.15rem] text-[color:var(--foreground)]">
                  {selected_identity(@formation.available_claims, @selected_claimed_label)}
                </p>
              </div>
            </div>

            <%= if @formation.billing_account.connected do %>
              <.inline_notice notice={
                %{
                  tone: :success,
                  message: "Billing is active. You can move on to opening the company."
                }
              } />
            <% else %>
              <.inline_notice notice={
                %{tone: :info, message: "Finish billing setup here to unlock company opening."}
              } />
            <% end %>
          </.form>
        </section>

        <div class="space-y-4">
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
            <div class="space-y-3">
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Billing status
                </p>
                <p class="mt-2 font-display text-[1.5rem] text-[color:var(--foreground)]">
                  {billing_value(@formation.billing_account)}
                </p>
              </div>

              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Credit balance
                </p>
                <p class="mt-2 font-display text-[1.5rem] text-[color:var(--foreground)]">
                  {format_usd_cents(@formation.billing_account.runtime_credit_balance_usd_cents)}
                </p>
              </div>

              <%= if @formation.billing_account.welcome_credit do %>
                <div class="rounded-[1.1rem] border border-[color:color-mix(in_oklch,var(--positive)_45%,var(--border)_55%)] bg-[color:color-mix(in_oklch,var(--positive)_9%,transparent)] p-4">
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Launch credit
                  </p>
                  <p class="mt-2 font-display text-[1.5rem] text-[color:var(--foreground)]">
                    {format_usd_cents(@formation.billing_account.welcome_credit.amount_usd_cents)}
                  </p>
                  <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                    Available until {format_credit_expiry(
                      @formation.billing_account.welcome_credit.expires_at
                    )}.
                  </p>
                </div>
              <% end %>
            </div>
          </section>

          <.setup_callout
            title="Company opening follows billing"
            copy="As soon as billing is active, Regents can open the hosted company with the name you selected here."
          >
            <%= if @formation.billing_account.connected do %>
              <.link
                navigate={~p"/app/formation?claimedLabel=#{@selected_claimed_label}"}
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
              >
                Continue to company opening
              </.link>
            <% else %>
              <button
                type="button"
                phx-click="start_billing_setup"
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
              >
                Set up billing
              </button>
            <% end %>
          </.setup_callout>
        </div>
      </div>
    </.setup_flow_frame>
    """
  end

  attr :formation, :map, required: true
  attr :selected_claimed_label, :string, default: nil
  attr :setup_form, :map, required: true

  def formation_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_formation(assigns.formation))
      |> assign(:facts, [
        %{
          icon: "hero-identification",
          title: "Chosen identity",
          copy: "The selected name becomes the company identity and public page."
        },
        %{
          icon: "hero-credit-card",
          title: "Payments active",
          copy: "Billing must already be on before launch can begin."
        },
        %{
          icon: "hero-building-office-2",
          title: "Hosted launch",
          copy: "Regents handles the company opening after you confirm the launch."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: 4,
          title: "Launch progress",
          copy: "We show live progress and move you into company controls when ready."
        }
      ])

    ~H"""
    <.setup_flow_frame
      step={4}
      title="Open company"
      summary="Confirm the claimed name you want to use, then launch the hosted company. Regents will reserve the identity, prepare the public page, and bring you into the company controls."
      snapshot={@snapshot}
      readiness={Map.get(@formation, :readiness)}
      facts={@facts}
      next_steps={@next_steps}
    >
      <div class="grid gap-5 xl:grid-cols-[minmax(0,0.98fr)_minmax(18rem,0.82fr)]">
        <section class="rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_12%,var(--border)_88%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--card)_90%,var(--background)_10%))] p-5 shadow-[0_24px_60px_-48px_color-mix(in_oklch,var(--brand-ink)_22%,transparent)] sm:p-6">
          <.form
            for={@setup_form}
            id="app-formation-form"
            phx-change="change_selected_claim"
            class="space-y-5"
          >
            <div class="space-y-2">
              <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Company launch
              </p>
              <h3 class="font-display text-[clamp(1.8rem,2.8vw,2.3rem)] leading-[0.92] text-[color:var(--foreground)]">
                Open the company with the name you selected.
              </h3>
              <p class="max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                This creates the hosted company, prepares the live page, and moves you into the company dashboard.
              </p>
            </div>

            <label class="space-y-2">
              <span class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                Claimed name
              </span>
              <.input
                field={@setup_form[:claimed_label]}
                type="select"
                options={formation_claim_options(@formation.available_claims)}
                class="w-full rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] outline-none transition focus:border-[color:var(--ring)]"
              />
            </label>

            <div class="grid gap-3 sm:grid-cols-2">
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Public company page
                </p>
                <p class="mt-2 font-display text-[1.15rem] text-[color:var(--foreground)]">
                  {selected_hostname(@selected_claimed_label)}
                </p>
              </div>

              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Claimed identity
                </p>
                <p class="mt-2 font-display text-[1.15rem] text-[color:var(--foreground)]">
                  {selected_identity(@formation.available_claims, @selected_claimed_label)}
                </p>
              </div>
            </div>

            <%= if @formation.billing_account.connected do %>
              <.inline_notice notice={
                %{tone: :success, message: "Billing is active. You can open the company now."}
              } />
            <% else %>
              <.inline_notice notice={
                %{tone: :info, message: "Finish billing first, then come back to launch the company."}
              } />
            <% end %>
          </.form>
        </section>

        <div class="space-y-4">
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
            <div class="space-y-3">
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Names ready to use
                </p>
                <div class="mt-3 grid gap-2">
                  <%= if @formation.available_claims == [] do %>
                    <p class="text-sm text-[color:var(--muted-foreground)]">
                      No claimed names are ready yet.
                    </p>
                  <% else %>
                    <%= for claim <- @formation.available_claims do %>
                      <div class="rounded-[0.95rem] border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-2.5 text-sm text-[color:var(--foreground)]">
                        {claim.ens_fqdn || "#{claim.label}.regent.eth"}
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Active company openings
                </p>
                <div class="mt-3 grid gap-2">
                  <%= if @formation.active_formations == [] do %>
                    <p class="text-sm text-[color:var(--muted-foreground)]">
                      No company is opening right now.
                    </p>
                  <% else %>
                    <%= for formation <- @formation.active_formations do %>
                      <div class="flex items-center justify-between gap-3 rounded-[0.95rem] border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-2.5">
                        <span class="text-sm text-[color:var(--foreground)]">
                          {formation.claimed_label || "Opening company"}
                        </span>
                        <span class={status_badge_class(formation.status)}>{formation.status}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </section>

          <.setup_callout
            title="Launch starts immediately"
            copy="After you confirm, Regents reserves the name, prepares the hosted company, and opens the live page before handing you off to the dashboard."
          >
            <%= if @formation.billing_account.connected do %>
              <button
                type="button"
                phx-click="start_company"
                class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
              >
                Open company
              </button>
            <% else %>
              <.link
                navigate={billing_back_path(@selected_claimed_label)}
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Back to billing
              </.link>
            <% end %>
          </.setup_callout>
        </div>
      </div>
    </.setup_flow_frame>
    """
  end

  attr :company, :map, required: true
  attr :formation, :map, default: nil

  def provisioning_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_company(assigns.company, assigns.formation))
      |> assign(:facts, [
        %{
          icon: "hero-sparkles",
          title: "Launch in progress",
          copy: "Regents is working through the final opening steps now."
        },
        %{
          icon: "hero-globe-alt",
          title: "Public page next",
          copy: "The public company page is opened before you land in the dashboard."
        },
        %{
          icon: "hero-command-line",
          title: "Controls after launch",
          copy: "When setup finishes, the company controls become your home."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: 4,
          title: "Finish opening",
          copy: "We complete the launch steps and move you into the dashboard automatically."
        }
      ])

    ~H"""
    <.setup_flow_frame
      step={4}
      title="Opening company"
      summary="The hosted company is being opened now. Stay here for a moment and Regents will take you into the dashboard as soon as setup is complete."
      snapshot={@snapshot}
      facts={@facts}
      next_steps={@next_steps}
    >
      <section
        id="app-provisioning-shell"
        phx-hook="LaunchProgress"
        class="space-y-5"
      >
        <section class="overflow-hidden rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_20%,var(--border)_80%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_95%,var(--background)_5%),color-mix(in_oklch,var(--background)_90%,var(--card)_10%))] px-5 py-6 shadow-[0_28px_90px_-56px_color-mix(in_oklch,var(--brand-ink)_30%,transparent)] sm:px-6">
          <div class="grid gap-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.8fr)]">
            <div class="pp-launch-progress-copy space-y-4">
              <div class="space-y-3">
                <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                  Opening now
                </p>
                <h3 class="font-display text-[clamp(2rem,4vw,3rem)] leading-[0.9] text-[color:var(--foreground)]">
                  We’re opening {@company.subdomain.hostname}
                </h3>
                <p class="max-w-[42rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Keep this page open. The dashboard will open automatically as soon as the final launch step completes.
                </p>
              </div>

              <div class="grid gap-3 sm:grid-cols-3">
                <div class="pp-launch-progress-card rounded-[1.3rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Company
                  </p>
                  <p class="mt-2 font-display text-[1.05rem] text-[color:var(--foreground)]">
                    {@company.name}
                  </p>
                </div>

                <div class="pp-launch-progress-card rounded-[1.3rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Current step
                  </p>
                  <p class="mt-2 font-display text-[1.05rem] text-[color:var(--foreground)]">
                    {launch_step_label(@formation)}
                  </p>
                </div>

                <div class="pp-launch-progress-card rounded-[1.3rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    What’s next
                  </p>
                  <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                    {launch_step_copy(@formation)}
                  </p>
                </div>
              </div>
            </div>

            <div class="pp-launch-progress-card rounded-[1.5rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] p-5">
              <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Launch checklist
              </p>

              <div class="mt-4 space-y-3">
                <%= for item <- launch_progress_items(@formation) do %>
                  <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                    <div class="flex items-center justify-between gap-3">
                      <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                        {item.title}
                      </p>
                      <span class={launch_progress_badge_class(item.state)}>{item.badge}</span>
                    </div>
                    <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      {item.copy}
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </section>
      </section>
    </.setup_flow_frame>
    """
  end

  attr :formation, :map, required: true
  attr :usage, :map, required: true
  attr :current_human, :map, required: true
  attr :holdings, :map, required: true
  attr :formation_token_cards, :map, required: true
  attr :shader_options, :list, required: true
  attr :avatar_save_notice, :map, default: nil
  attr :notice, :map, default: nil
  attr :notices, :list, default: []

  def dashboard_stage(assigns) do
    assigns =
      assigns
      |> assign(:snapshot, setup_snapshot_from_formation(assigns.formation))
      |> assign(:facts, [
        %{
          icon: "hero-building-office-2",
          title: "Company live",
          copy: "Your hosted company is ready to manage from one place."
        },
        %{
          icon: "hero-credit-card",
          title: "Billing visible",
          copy: "Credit, spend, and company counts stay visible while you work."
        },
        %{
          icon: "hero-paint-brush",
          title: "Public look",
          copy: "Save the avatar that appears across your public company pages."
        }
      ])
      |> assign(:next_steps, [
        %{
          number: "Live",
          title: "Use the public page",
          copy: "Open the live company page or continue into company controls here."
        },
        %{
          number: "CLI",
          title: "Move into Regents CLI",
          copy: "Use the CLI when work starts on a machine or inside an agent."
        }
      ])

    ~H"""
    <.setup_flow_frame
      step={4}
      title="Company dashboard"
      summary="Control the hosted company from here. Review company status, billing, and public presentation here, then move into the next lane when you are ready."
      snapshot={@snapshot}
      readiness={Map.get(@formation, :readiness)}
      facts={@facts}
      next_steps={@next_steps}
    >
      <div :if={@notices != []} class="mb-5 space-y-3">
        <.inline_notice :for={notice <- @notices} notice={notice} />
      </div>

      <.inline_notice :if={@notices == [] and @notice} notice={@notice} class="mb-5" />

      <section class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_14%,var(--border)_86%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--card)_88%,var(--background)_12%))] p-5 shadow-[0_24px_60px_-48px_color-mix(in_oklch,var(--brand-ink)_22%,transparent)] sm:p-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-2">
            <p class="text-[11px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Live company
            </p>
            <h3 class="font-display text-[clamp(1.9rem,3vw,2.5rem)] leading-[0.92] text-[color:var(--foreground)]">
              Manage every hosted company from one place.
            </h3>
            <p class="max-w-[38rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
              Review company status, public pages, account spend, and saved avatar choices without leaving the dashboard.
            </p>
          </div>

          <.link
            navigate={~p"/app/formation"}
            class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
          >
            Open another company
          </.link>
        </div>

        <div class="mt-5 grid gap-3 md:grid-cols-5">
          <.metric_tile
            label="Billing"
            value={billing_value(@formation.billing_account)}
            copy="Shared across your hosted companies."
          />
          <.metric_tile
            label="Credit balance"
            value={format_usd_cents(@usage.runtime_credit_balance_usd_cents)}
            copy="Available company credit."
          />
          <.metric_tile
            label="Runtime spend"
            value={format_usd_cents(@usage.runtime_spend_usd_cents)}
            copy="Recorded company runtime spend."
          />
          <.metric_tile
            label="Model spend"
            value={format_usd_cents(@usage.llm_spend_usd_cents)}
            copy="Recorded model usage spend."
          />
          <.metric_tile
            label="Opened companies"
            value={Integer.to_string(length(@formation.owned_companies))}
            copy="Companies tied to this account."
          />
        </div>
      </section>

      <div class="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1.02fr)_minmax(18rem,0.78fr)]">
        <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                Companies
              </p>
              <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                Review the state of each hosted company and open the live page or change runtime state.
              </p>
            </div>
          </div>

          <div class="mt-4 space-y-3">
            <%= if @formation.owned_companies == [] do %>
              <div class="rounded-[1.2rem] border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                No companies have been opened yet.
              </div>
            <% else %>
              <%= for company <- @formation.owned_companies do %>
                <article class="rounded-[1.25rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p class="font-display text-xl text-[color:var(--foreground)]">
                        {company.name}
                      </p>
                      <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                        {(company.subdomain && company.subdomain.hostname) ||
                          "#{company.slug}.regents.sh"}
                      </p>
                    </div>
                    <span class={status_badge_class(company.runtime_status)}>
                      {company.runtime_status}
                    </span>
                  </div>

                  <div class="mt-4 grid gap-3 sm:grid-cols-3">
                    <div class="rounded-[1rem] border border-[color:var(--border)] px-3 py-3">
                      <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                        Company state
                      </p>
                      <p class="mt-2 text-sm text-[color:var(--foreground)]">{company.status}</p>
                    </div>
                    <div class="rounded-[1rem] border border-[color:var(--border)] px-3 py-3">
                      <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                        Billing state
                      </p>
                      <p class="mt-2 text-sm text-[color:var(--foreground)]">
                        {company.sprite_metering_status}
                      </p>
                    </div>
                    <div class="rounded-[1rem] border border-[color:var(--border)] px-3 py-3">
                      <p class="text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]">
                        Current setting
                      </p>
                      <p class="mt-2 text-sm text-[color:var(--foreground)]">
                        {company.desired_runtime_state}
                      </p>
                    </div>
                  </div>

                  <div class="mt-4 flex flex-wrap gap-3">
                    <a
                      href={"https://#{company.subdomain.hostname}"}
                      target="_blank"
                      rel="noreferrer"
                      class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                    >
                      Open public page
                    </a>
                    <%= if company.desired_runtime_state == "paused" do %>
                      <button
                        type="button"
                        phx-click="resume_company"
                        phx-value-slug={company.slug}
                        class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
                      >
                        Resume company
                      </button>
                    <% else %>
                      <button
                        type="button"
                        phx-click="pause_company"
                        phx-value-slug={company.slug}
                        class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        Pause company
                      </button>
                    <% end %>
                  </div>
                </article>
              <% end %>
            <% end %>
          </div>
        </section>

        <div class="space-y-4">
          <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
            <div class="space-y-3">
              <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Billing summary
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Paid companies:
                  <span class="text-[color:var(--foreground)]">{@usage.paid_companies}</span>
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Paused companies:
                  <span class="text-[color:var(--foreground)]">{@usage.paused_companies}</span>
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Trialing companies:
                  <span class="text-[color:var(--foreground)]">{@usage.trialing_companies}</span>
                </p>
              </div>

              <%= if active_formation?(@formation) do %>
                <div class="rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] p-4">
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Opening now
                  </p>
                  <div class="mt-3 space-y-2">
                    <%= for formation <- @formation.active_formations do %>
                      <.link
                        navigate={~p"/app/provisioning/#{formation.id}"}
                        class="flex items-center justify-between gap-3 rounded-[0.95rem] border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        <span>{formation.claimed_label || "Opening company"}</span>
                        <span aria-hidden="true">→</span>
                      </.link>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </section>

          <.setup_callout
            title="Next lanes"
            copy="When the company is live, continue with the public page, company controls, Regents CLI, Techtree, or Autolaunch from here."
          >
            <.link
              navigate={~p"/docs"}
              class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
            >
              Open docs
            </.link>
          </.setup_callout>
        </div>
      </div>

      <section
        id="app-dashboard-avatar-creator"
        class="mt-5 grid gap-5 xl:grid-cols-[minmax(0,0.82fr)_minmax(0,1.18fr)]"
      >
        <section class="space-y-4 rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
          <div class="space-y-2">
            <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
              Agent Avatar Creator
            </p>
            <h3 class="font-display text-2xl text-[color:var(--foreground)]">
              Choose the saved look for your public company pages.
            </h3>
            <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
              Pick an owned collection avatar or save a shader look. Regents Club keeps the gold border on the public company page.
            </p>
          </div>

          <%= if @avatar_save_notice do %>
            <.inline_notice notice={@avatar_save_notice} />
          <% end %>

          <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
            <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
              Current saved avatar
            </p>

            <%= if current_avatar_token_card?(@current_human.avatar, @formation_token_cards) do %>
              <div class="mt-4 max-w-[16rem]">
                <div
                  data-token-card-root
                  data-token-card-entry={
                    current_avatar_token_card_payload(@current_human.avatar, @formation_token_cards)
                  }
                  data-token-card-layout="embedded"
                  data-token-card-active="true"
                >
                </div>
              </div>
            <% else %>
              <div class={current_avatar_card_class(@current_human.avatar)}>
                <p class="font-display text-[1.35rem] text-[color:var(--foreground)]">
                  {AvatarSelection.current_label(@current_human.avatar)}
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  {current_avatar_copy(@current_human.avatar)}
                </p>
              </div>
            <% end %>
          </div>

          <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
            <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
              Gold border rule
            </p>
            <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
              The gold border only appears when the saved avatar is a Regents Club choice. Shader looks and other collection picks use the standard frame.
            </p>
          </div>
        </section>

        <section class="space-y-4 rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
          <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Collection I
                  </p>
                  <p class="mt-2 text-sm text-[color:var(--muted-foreground)]">
                    Save one of your Collection I avatars.
                  </p>
                </div>
                <span class="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]">
                  {length(Map.get(@holdings, "animata1", []))}
                </span>
              </div>
              <div class="mt-4 flex flex-wrap gap-2">
                <%= if Map.get(@holdings, "animata1", []) == [] do %>
                  <span class="text-sm text-[color:var(--muted-foreground)]">
                    No Collection I avatars found.
                  </span>
                <% else %>
                  <%= for token_id <- Map.get(@holdings, "animata1", []) do %>
                    <button
                      id={"dashboard-avatar-animata1-#{token_id}"}
                      type="button"
                      phx-click="save_avatar"
                      phx-value-kind="collection_token"
                      phx-value-collection="animata1"
                      phx-value-token_id={token_id}
                      class={avatar_choice_button_class(@current_human.avatar, "animata1", token_id)}
                    >
                      Collection I #{token_id}
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Collection II
                  </p>
                  <p class="mt-2 text-sm text-[color:var(--muted-foreground)]">
                    Save one of your Collection II avatars.
                  </p>
                </div>
                <span class="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]">
                  {length(Map.get(@holdings, "animata2", []))}
                </span>
              </div>
              <div class="mt-4 flex flex-wrap gap-2">
                <%= if Map.get(@holdings, "animata2", []) == [] do %>
                  <span class="text-sm text-[color:var(--muted-foreground)]">
                    No Collection II avatars found.
                  </span>
                <% else %>
                  <%= for token_id <- Map.get(@holdings, "animata2", []) do %>
                    <button
                      id={"dashboard-avatar-animata2-#{token_id}"}
                      type="button"
                      phx-click="save_avatar"
                      phx-value-kind="collection_token"
                      phx-value-collection="animata2"
                      phx-value-token_id={token_id}
                      class={avatar_choice_button_class(@current_human.avatar, "animata2", token_id)}
                    >
                      Collection II #{token_id}
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Regents Club
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Regents Club keeps the gold border on public company pages.
                </p>
              </div>
              <span class="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]">
                {length(Map.get(@holdings, "animataPass", []))}
              </span>
            </div>

            <div
              id="app-dashboard-pass-gallery"
              phx-hook="FormationPassGallery"
              data-token-card-budget="6"
              data-token-card-chunk="2"
              class="mt-5 grid justify-items-center gap-x-5 gap-y-6 sm:grid-cols-2 xl:grid-cols-3"
            >
              <%= if Map.get(@holdings, "animataPass", []) == [] do %>
                <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)] sm:col-span-2 xl:col-span-3">
                  No Regents Club passes found for this wallet.
                </div>
              <% else %>
                <%= for token_id <- Map.get(@holdings, "animataPass", []) do %>
                  <button
                    id={"dashboard-avatar-animata-pass-#{token_id}"}
                    type="button"
                    phx-click="save_avatar"
                    phx-value-kind="collection_token"
                    phx-value-collection="animataPass"
                    phx-value-token_id={token_id}
                    class={[
                      "group inline-flex shrink-0 transition hover:-translate-y-1",
                      avatar_token_card_button_class(@current_human.avatar, token_id)
                    ]}
                  >
                    <%= if entry = Map.get(@formation_token_cards, token_id) do %>
                      <div
                        data-token-card-root
                        data-token-card-entry={TokenCardPayload.encode(entry)}
                        data-token-card-layout="embedded"
                        data-token-card-active="true"
                      >
                      </div>
                    <% else %>
                      <div class="flex min-h-[22rem] min-w-[15rem] items-center justify-center rounded-[1.2rem] border border-dashed border-[color:var(--border)] px-4 text-center text-xs uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                        Card unavailable
                      </div>
                    <% end %>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p class="text-[11px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Shader looks
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Save one of these shader looks as the account-level avatar.
                </p>
              </div>

              <.link
                navigate={~p"/shader"}
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Open shader studio
              </.link>
            </div>

            <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              <%= for shader <- @shader_options do %>
                <button
                  id={"dashboard-avatar-shader-#{shader.id}"}
                  type="button"
                  phx-click="save_avatar"
                  phx-value-kind="custom_shader"
                  phx-value-shader_id={shader.id}
                  class={shader_choice_button_class(@current_human.avatar, shader.id)}
                >
                  <span class="font-display text-[1.1rem] text-[color:var(--foreground)]">
                    {shader.title}
                  </span>
                  <span class="mt-2 text-left text-sm leading-6 text-[color:var(--muted-foreground)]">
                    {shader.description}
                  </span>
                </button>
              <% end %>
            </div>
          </div>
        </section>
      </section>
    </.setup_flow_frame>
    """
  end

  attr :step, :integer, required: true
  attr :title, :string, required: true
  attr :summary, :string, required: true
  attr :snapshot, :map, required: true
  attr :readiness, :map, default: nil
  attr :facts, :list, default: []
  attr :next_steps, :list, default: []
  slot :inner_block, required: true

  def setup_flow_frame(assigns) do
    ~H"""
    <div class="grid gap-6 xl:grid-cols-[17.5rem_minmax(0,1fr)_20rem]">
      <aside data-dashboard-block class="xl:sticky xl:top-6 xl:self-start">
        <.setup_step_rail step={@step} snapshot={@snapshot} />
      </aside>

      <main data-dashboard-block class="min-w-0">
        <section class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--border)_90%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_98%,var(--background)_2%),color-mix(in_oklch,var(--background)_94%,var(--card)_6%))] p-5 shadow-[0_30px_80px_-60px_color-mix(in_oklch,var(--brand-ink)_24%,transparent)] sm:p-7">
          <div class="space-y-3">
            <p class="text-[11px] uppercase tracking-[0.28em] text-[color:var(--muted-foreground)]">
              Step {@step} of 4
            </p>
            <h2 class="font-display text-[clamp(2.2rem,4vw,3.2rem)] leading-[0.9] text-[color:var(--foreground)]">
              {@title}
            </h2>
            <p class="max-w-[44rem] text-sm leading-7 text-[color:var(--muted-foreground)]">
              {@summary}
            </p>
          </div>

          <div class="mt-6 grid gap-3 md:grid-cols-3">
            <%= for fact <- @facts do %>
              <article class="rounded-[1.3rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_96%,transparent)] p-4">
                <div class="flex items-start gap-3">
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[color:color-mix(in_oklch,var(--brand-ink)_12%,transparent)] text-[color:var(--brand-ink)]">
                    <.icon name={fact.icon} class="h-5 w-5" />
                  </div>
                  <div class="space-y-1">
                    <p class="font-display text-[1.02rem] text-[color:var(--foreground)]">
                      {fact.title}
                    </p>
                    <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                      {fact.copy}
                    </p>
                  </div>
                </div>
              </article>
            <% end %>
          </div>

          <div class="mt-7 border-t border-[color:var(--border)] pt-7">
            {render_slot(@inner_block)}
          </div>
        </section>
      </main>

      <aside data-dashboard-block class="xl:sticky xl:top-6 xl:self-start">
        <.setup_status_sidebar
          step={@step}
          snapshot={@snapshot}
          readiness={@readiness}
          next_steps={@next_steps}
        />
      </aside>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :snapshot, :map, required: true

  def setup_step_rail(assigns) do
    ~H"""
    <div class="space-y-4">
      <section class="rounded-[1.9rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_98%,var(--background)_2%),color-mix(in_oklch,var(--background)_95%,var(--card)_5%))] p-5 shadow-[0_22px_48px_-42px_color-mix(in_oklch,var(--brand-ink)_18%,transparent)]">
        <div class="space-y-2">
          <h3 class="font-display text-[2rem] leading-[0.92] text-[color:var(--foreground)]">
            App setup
          </h3>
          <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
            Complete each step to open your agent company.
          </p>
        </div>

        <div class="mt-6 space-y-4">
          <%= for {item, index} <- Enum.with_index(setup_step_items(@snapshot, @step)) do %>
            <div class="flex gap-4">
              <div class="flex w-9 flex-col items-center">
                <div class={setup_step_circle_class(item.state)}>
                  <%= if item.state == :complete do %>
                    <.icon name="hero-check" class="h-4 w-4" />
                  <% else %>
                    {item.number}
                  <% end %>
                </div>
                <div
                  :if={index < 3}
                  class="mt-2 h-10 w-px bg-[color:color-mix(in_oklch,var(--border)_78%,var(--brand-ink)_22%)]"
                >
                </div>
              </div>

              <.link navigate={item.path} class="block min-w-0 pt-0.5">
                <p class={setup_step_title_class(item.state)}>{item.title}</p>
                <p class="mt-1 text-sm leading-5 text-[color:var(--muted-foreground)]">
                  {item.copy}
                </p>
              </.link>
            </div>
          <% end %>
        </div>
      </section>

      <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
        <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
          Why these steps?
        </p>
        <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
          Regents guides access, identity, billing, and launch in order so the company is ready to go live without guesswork.
        </p>
      </section>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :snapshot, :map, required: true
  attr :readiness, :map, default: nil
  attr :next_steps, :list, default: []

  def setup_status_sidebar(assigns) do
    ~H"""
    <div class="space-y-4">
      <section class="rounded-[1.9rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_98%,var(--background)_2%),color-mix(in_oklch,var(--background)_95%,var(--card)_5%))] p-5 shadow-[0_22px_48px_-42px_color-mix(in_oklch,var(--brand-ink)_18%,transparent)]">
        <div class="space-y-4">
          <div>
            <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
              Your setup status
            </p>
          </div>

          <div class="rounded-[1.3rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm text-[color:var(--foreground)]">Overall progress</p>
              <p class="text-sm text-[color:var(--muted-foreground)]">
                {setup_progress_percent(@snapshot)}%
              </p>
            </div>
            <div class="mt-4 h-2 overflow-hidden rounded-full bg-[color:color-mix(in_oklch,var(--background)_70%,var(--border)_30%)]">
              <div
                class="h-full rounded-full bg-[color:var(--brand-ink)] transition-all duration-500"
                style={"width: #{setup_progress_percent(@snapshot)}%"}
              >
              </div>
            </div>
            <p class="mt-3 text-sm text-[color:var(--muted-foreground)]">
              {setup_completed_steps(@snapshot)} of 4 steps complete
            </p>
          </div>

          <div class="space-y-3">
            <%= for card <- setup_status_cards(@snapshot) do %>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-sm text-[color:var(--foreground)]">{card.label}</p>
                    <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">{card.copy}</p>
                  </div>
                  <span class={setup_state_chip_class(card.tone)}>{card.state}</span>
                </div>
              </div>
            <% end %>
          </div>

          <div :if={readiness_steps(@readiness) != []} class="space-y-3">
            <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
              Readiness checklist
            </p>
            <%= for step <- readiness_steps(@readiness) do %>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-sm text-[color:var(--foreground)]">{step.label}</p>
                    <p class="mt-1 text-sm leading-5 text-[color:var(--muted-foreground)]">
                      {step.message}
                    </p>
                  </div>
                  <span class={readiness_state_chip_class(step.status)}>
                    {readiness_status_label(step.status)}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <section class="rounded-[1.9rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
        <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
          What happens next
        </p>

        <div class="mt-4 space-y-4">
          <%= for item <- @next_steps do %>
            <div class="flex gap-4">
              <div class="flex w-7 flex-col items-center">
                <div class="flex h-7 w-7 items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] text-xs text-[color:var(--foreground)]">
                  {item.number}
                </div>
              </div>
              <div class="min-w-0">
                <p class="text-sm text-[color:var(--foreground)]">{item.title}</p>
                <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  {item.copy}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </section>

      <section class="rounded-[1.9rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
        <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
          Need help?
        </p>
        <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
          Visit the docs or open a support ticket.
        </p>
        <div class="mt-4 flex flex-wrap gap-3">
          <.link
            navigate={~p"/docs"}
            class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
          >
            View docs
          </.link>
          <.link
            navigate={~p"/bug-report"}
            class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
          >
            Get support
          </.link>
        </div>
      </section>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :copy, :string, required: true
  slot :inner_block

  def setup_callout(assigns) do
    ~H"""
    <section class="rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_14%,var(--border)_86%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_8%,transparent),color-mix(in_oklch,var(--background)_95%,transparent))] p-5">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="space-y-1">
          <p class="font-display text-[1.3rem] text-[color:var(--foreground)]">{@title}</p>
          <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">{@copy}</p>
        </div>
        <div class="shrink-0">
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end

  attr :step, :integer, required: true
  attr :title, :string, required: true
  attr :summary, :string, required: true
  attr :snapshot, :map, required: true
  attr :readiness, :map, default: nil
  attr :facts, :list, default: []
  attr :next_steps, :list, default: []
  attr :blocker_copy, :string, required: true
  attr :action_label, :string, required: true
  attr :action_path, :string, required: true
  attr :action_copy, :string, default: nil
  attr :notice, :map, default: nil

  def setup_blocked_stage(assigns) do
    ~H"""
    <.setup_flow_frame
      step={@step}
      title={@title}
      summary={@summary}
      snapshot={@snapshot}
      readiness={@readiness}
      facts={@facts}
      next_steps={@next_steps}
    >
      <.inline_notice :if={@notice} notice={@notice} class="mb-5" />

      <div class="grid gap-5 lg:grid-cols-2">
        <section class="rounded-[1.7rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_12%,var(--border)_88%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--card)_90%,var(--background)_10%))] p-5">
          <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
            Current blocker
          </p>
          <p class="mt-3 text-sm leading-7 text-[color:var(--foreground)]">
            {@blocker_copy}
          </p>
        </section>

        <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] p-5">
          <p class="text-[11px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
            What to do now
          </p>
          <p class="mt-3 text-sm leading-7 text-[color:var(--foreground)]">
            {@action_copy || @blocker_copy}
          </p>
        </section>
      </div>

      <div class="mt-5">
        <.setup_callout
          title="Keep the setup flow moving"
          copy="Finish the missing step and come right back here. The next action will unlock as soon as the blocker is cleared."
        >
          <.link
            navigate={@action_path}
            class="inline-flex items-center justify-center rounded-full bg-[color:var(--brand-ink)] px-4 py-2.5 text-sm text-white transition hover:brightness-110"
          >
            {@action_label}
          </.link>
        </.setup_callout>
      </div>
    </.setup_flow_frame>
    """
  end

  def setup_snapshot_from_services(services) do
    %{
      wallet_connected?: Map.get(services, :authenticated, false) == true,
      pass_ready?: eligible_services?(services),
      claimable_names: available_claim_count(services),
      billing_status: :not_started,
      company_opened?: false,
      company_opening?: false
    }
  end

  def setup_snapshot_from_formation(nil), do: empty_setup_snapshot()

  def setup_snapshot_from_formation(formation) do
    %{
      wallet_connected?: Map.get(formation, :authenticated, false) == true,
      pass_ready?:
        Map.get(formation, :eligible, false) == true or total_eligible_tokens(formation) > 0,
      claimable_names: available_claim_count(formation),
      billing_status: setup_billing_status(Map.get(formation, :billing_account)),
      company_opened?: owned_company_count(formation) > 0,
      company_opening?: active_formation?(formation)
    }
  end

  def setup_snapshot_from_company(company, formation) do
    formation_snapshot =
      setup_snapshot_from_formation(%{
        authenticated: true,
        eligible: true,
        available_claims: [],
        billing_account: %{connected: true},
        owned_companies: if(company, do: [company], else: []),
        active_formations: if(formation, do: [formation], else: [])
      })

    %{
      formation_snapshot
      | company_opened?: formation && formation.status == "succeeded",
        company_opening?: formation_active?(formation)
    }
  end

  defp formation_active?(%{status: status}) when status in ["queued", "running"], do: true
  defp formation_active?(_formation), do: false

  defp empty_setup_snapshot do
    %{
      wallet_connected?: false,
      pass_ready?: false,
      claimable_names: 0,
      billing_status: :not_started,
      company_opened?: false,
      company_opening?: false
    }
  end

  defp setup_billing_status(%{connected: true}), do: :connected
  defp setup_billing_status(%{status: "checkout_open"}), do: :pending
  defp setup_billing_status(_billing), do: :not_started

  defp available_claim_count(%{available_claims: claims}) when is_list(claims), do: length(claims)
  defp available_claim_count(_source), do: 0

  defp owned_company_count(%{owned_companies: companies}) when is_list(companies),
    do: length(companies)

  defp owned_company_count(_source), do: 0

  defp setup_completed_steps(snapshot) do
    [
      snapshot.wallet_connected? and snapshot.pass_ready?,
      snapshot.claimable_names > 0,
      snapshot.billing_status == :connected,
      snapshot.company_opened?
    ]
    |> Enum.count(& &1)
  end

  defp setup_progress_percent(snapshot), do: round(setup_completed_steps(snapshot) / 4 * 100)

  defp setup_step_items(snapshot, current_step) do
    [
      %{number: 1, title: "Check access", copy: "Wallet and pass status", path: "/app/access"},
      %{
        number: 2,
        title: "Claim identity",
        copy: "Choose your company name",
        path: "/app/identity"
      },
      %{number: 3, title: "Add billing", copy: "Activate payments", path: "/app/billing"},
      %{number: 4, title: "Open company", copy: "Launch your company", path: "/app/formation"}
    ]
    |> Enum.map(fn item ->
      Map.put(item, :state, setup_step_state(item.number, snapshot, current_step))
    end)
  end

  defp setup_step_state(1, snapshot, _current_step) do
    if snapshot.wallet_connected? and snapshot.pass_ready?, do: :complete, else: :current
  end

  defp setup_step_state(2, snapshot, current_step) do
    cond do
      snapshot.claimable_names > 0 -> :complete
      current_step == 2 -> :current
      true -> :upcoming
    end
  end

  defp setup_step_state(3, snapshot, current_step) do
    cond do
      snapshot.billing_status == :connected -> :complete
      current_step == 3 -> :current
      true -> :upcoming
    end
  end

  defp setup_step_state(4, snapshot, current_step) do
    cond do
      snapshot.company_opened? -> :complete
      current_step == 4 -> :current
      true -> :upcoming
    end
  end

  defp setup_step_circle_class(:complete),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] text-[color:var(--positive)]"

  defp setup_step_circle_class(:current),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--ring)] bg-[color:color-mix(in_oklch,var(--ring)_10%,transparent)] text-[color:var(--brand-ink)]"

  defp setup_step_circle_class(:upcoming),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] text-[color:var(--muted-foreground)]"

  defp setup_step_title_class(:complete), do: "text-sm text-[color:var(--foreground)]"
  defp setup_step_title_class(:current), do: "text-sm text-[color:var(--brand-ink)]"
  defp setup_step_title_class(:upcoming), do: "text-sm text-[color:var(--foreground)]"

  defp setup_status_cards(snapshot) do
    [
      %{
        label: "Wallet",
        copy: if(snapshot.wallet_connected?, do: "Ready for setup", else: "Sign in to continue"),
        state: if(snapshot.wallet_connected?, do: "Connected", else: "Action needed"),
        tone: if(snapshot.wallet_connected?, do: :success, else: :warning)
      },
      %{
        label: "Pass access",
        copy:
          if(snapshot.pass_ready?, do: "This wallet qualifies", else: "Qualifying pass required"),
        state: if(snapshot.pass_ready?, do: "Ready", else: "Action needed"),
        tone: if(snapshot.pass_ready?, do: :success, else: :warning)
      },
      %{
        label: "Claimable names",
        copy: "#{snapshot.claimable_names} names ready",
        state: if(snapshot.claimable_names > 0, do: "Ready", else: "Action needed"),
        tone: if(snapshot.claimable_names > 0, do: :success, else: :warning)
      },
      %{
        label: "Billing",
        copy: setup_billing_copy(snapshot.billing_status),
        state: setup_billing_label(snapshot.billing_status),
        tone: setup_billing_tone(snapshot.billing_status)
      }
    ]
  end

  defp setup_billing_label(:connected), do: "Connected"
  defp setup_billing_label(:pending), do: "Pending"
  defp setup_billing_label(:not_started), do: "Not started"

  defp setup_billing_copy(:connected), do: "Billing is active"
  defp setup_billing_copy(:pending), do: "Finishing setup"
  defp setup_billing_copy(:not_started), do: "Add a payment method"

  defp setup_billing_tone(:connected), do: :success
  defp setup_billing_tone(:pending), do: :warning
  defp setup_billing_tone(:not_started), do: :neutral

  defp setup_state_chip_class(:success),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  defp setup_state_chip_class(:warning),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,#c58a24_48%,var(--border)_52%)] bg-[color:color-mix(in_oklch,#c58a24_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  defp setup_state_chip_class(:neutral),
    do:
      "rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-1 text-xs text-[color:var(--muted-foreground)]"

  defp readiness_steps(%{steps: steps}) when is_list(steps), do: steps
  defp readiness_steps(_readiness), do: []

  defp readiness_status_label("complete"), do: "Ready"
  defp readiness_status_label("ready"), do: "Ready"
  defp readiness_status_label("needs_action"), do: "Needs action"
  defp readiness_status_label("waiting"), do: "Waiting"
  defp readiness_status_label(_status), do: "Waiting"

  defp readiness_state_chip_class(status) when status in ["complete", "ready"],
    do: setup_state_chip_class(:success)

  defp readiness_state_chip_class("needs_action"), do: setup_state_chip_class(:warning)
  defp readiness_state_chip_class(_status), do: setup_state_chip_class(:neutral)

  defp name_claim_badge_class(true),
    do:
      "rounded-full border border-[color:#a6574f] bg-[color:color-mix(in_oklch,#a6574f_10%,transparent)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:#a6574f]"

  defp name_claim_badge_class(false),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,#c58a24_48%,var(--border)_52%)] bg-[color:color-mix(in_oklch,#c58a24_10%,transparent)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]"

  defp billing_next_ready_path(%{available_claims: [claim | _]}),
    do: "/app/billing?claimedLabel=#{claim.label}"

  defp billing_next_ready_path(_services), do: "/app/billing"

  defp launch_progress_items(formation) do
    steps = [
      %{
        key: "reserve_claim",
        title: "Reserve company name",
        copy: "We reserve the identity and lock in the selected name."
      },
      %{
        key: "create_sprite",
        title: "Prepare hosted company",
        copy: "The hosted environment is being set up for launch."
      },
      %{
        key: "bootstrap_workspace",
        title: "Build company workspace",
        copy: "The company workspace and assistant are being prepared."
      },
      %{
        key: "verify_runtime",
        title: "Check company response",
        copy: "We confirm the company is responding before opening it."
      },
      %{
        key: "activate_subdomain",
        title: "Open public page",
        copy: "The live public company page is being switched on."
      },
      %{
        key: "finalize",
        title: "Open dashboard",
        copy: "Final checks finish before the dashboard opens."
      }
    ]

    current_step = formation && launch_progress_step_key(formation.current_step)
    current_index = Enum.find_index(steps, &(&1.key == current_step)) || 0

    steps
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      state =
        cond do
          formation && formation.status == "succeeded" -> :complete
          index < current_index -> :complete
          index == current_index -> :current
          true -> :upcoming
        end

      badge =
        case state do
          :complete -> "Done"
          :current -> "Working"
          :upcoming -> "Next"
        end

      Map.merge(item, %{state: state, badge: badge})
    end)
  end

  defp launch_progress_badge_class(:complete),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  defp launch_progress_badge_class(:current),
    do:
      "rounded-full border border-[color:var(--ring)] bg-[color:color-mix(in_oklch,var(--ring)_10%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  defp launch_progress_badge_class(:upcoming),
    do:
      "rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-1 text-xs text-[color:var(--muted-foreground)]"

  attr :state, :map, required: true

  def availability_state(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if @state.label_error do %>
        <p class="text-sm text-[color:#a6574f]">{@state.label_error}</p>
      <% end %>

      <%= if @state.valid? do %>
        <div class="flex flex-wrap gap-2 text-xs uppercase tracking-[0.16em]">
          <span class={availability_badge_class(@state)}>{availability_badge_label(@state)}</span>
          <span
            :if={@state.ens_fqdn}
            class="rounded-full border border-[color:var(--border)] px-3 py-1 text-[color:var(--muted-foreground)]"
          >
            {@state.ens_fqdn}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  attr :notice, :map, required: true
  attr :class, :string, default: nil

  def inline_notice(assigns) do
    ~H"""
    <div class={["rounded-2xl border px-4 py-3 text-sm leading-6", notice_class(@notice.tone), @class]}>
      {@notice.message}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :copy, :string, required: true

  def metric_tile(assigns) do
    ~H"""
    <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] p-4">
      <div class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
        {@label}
      </div>
      <div class="mt-3 font-display text-2xl text-[color:var(--foreground)]">{@value}</div>
      <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">{@copy}</p>
    </div>
    """
  end

  defp avatar_choice_button_class(current_avatar, collection, token_id) do
    selected? =
      current_avatar_kind?(current_avatar, "collection_token") and
        current_avatar["collection"] == collection and current_avatar["token_id"] == token_id

    [
      "inline-flex items-center justify-center rounded-full border px-4 py-2 text-sm transition",
      if(selected?,
        do:
          "border-[color:var(--ring)] bg-[color:color-mix(in_oklch,var(--ring)_14%,transparent)] text-[color:var(--foreground)]",
        else:
          "border-[color:var(--border)] text-[color:var(--foreground)] hover:border-[color:var(--ring)]"
      )
    ]
  end

  defp shader_choice_button_class(current_avatar, shader_id) do
    selected? =
      current_avatar_kind?(current_avatar, "custom_shader") and
        current_avatar["shader_id"] == shader_id

    [
      "flex min-h-[10rem] flex-col items-start rounded-[1.2rem] border px-4 py-4 text-left transition",
      if(selected?,
        do:
          "border-[color:var(--ring)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--ring)_14%,transparent),color-mix(in_oklch,var(--background)_94%,transparent))]",
        else: "border-[color:var(--border)] hover:border-[color:var(--ring)]"
      )
    ]
  end

  defp avatar_token_card_button_class(current_avatar, token_id) do
    selected? =
      current_avatar_kind?(current_avatar, "collection_token") and
        current_avatar["collection"] == "animataPass" and current_avatar["token_id"] == token_id

    if selected?,
      do:
        "rounded-[1.4rem] ring-2 ring-[color:var(--ring)] ring-offset-4 ring-offset-[color:var(--card)]",
      else: ""
  end

  defp current_avatar_kind?(%{"kind" => kind}, expected_kind), do: kind == expected_kind
  defp current_avatar_kind?(_avatar, _expected_kind), do: false

  defp current_avatar_copy(nil),
    do: "Save a look here and it will show on every public company page you own."

  defp current_avatar_copy(%{"kind" => "custom_shader", "shader_id" => shader_id}) do
    AvatarSelection.shader_description(shader_id)
  end

  defp current_avatar_copy(%{
         "kind" => "collection_token",
         "collection" => collection,
         "token_id" => token_id
       }) do
    "#{AvatarSelection.collection_label(collection)} ##{token_id} is saved for every public company page on this account."
  end

  defp current_avatar_copy(_avatar),
    do: "Save a look here and it will show on every public company page you own."

  defp current_avatar_card_class(avatar) do
    [
      "mt-4 rounded-[1.4rem] border p-5",
      if(AvatarSelection.gold_border?(avatar),
        do:
          "border-[color:color-mix(in_oklch,#d4a756_72%,var(--border)_28%)] bg-[linear-gradient(180deg,color-mix(in_oklch,#d4a756_16%,transparent),color-mix(in_oklch,var(--background)_94%,transparent))]",
        else:
          "border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_10%,transparent),color-mix(in_oklch,var(--background)_94%,transparent))]"
      )
    ]
  end

  defp current_avatar_token_card?(
         %{"kind" => "collection_token", "collection" => "animataPass", "token_id" => token_id},
         token_cards
       ) do
    Map.has_key?(token_cards, token_id)
  end

  defp current_avatar_token_card?(_avatar, _token_cards), do: false

  defp current_avatar_token_card_payload(%{"token_id" => token_id}, token_cards) do
    token_cards
    |> Map.fetch!(token_id)
    |> TokenCardPayload.encode()
  end

  defp eligible_services?(services),
    do:
      length(services.holdings.animata1) + length(services.holdings.animata2) +
        length(services.holdings.animata_pass) > 0

  defp access_blocker_copy(%{authenticated: false}),
    do: "Sign in first so the app can read this wallet."

  defp access_blocker_copy(services) do
    if eligible_services?(services) do
      "This wallet can continue."
    else
      "This wallet still needs a qualifying pass."
    end
  end

  defp can_free_claim?(services, state, wallet_ready?) do
    wallet_ready? and is_map(services.allowance) and services.allowance.free_mints_remaining > 0 and
      state.valid? and state.available? == true and not state.reserved?
  end

  defp can_paid_claim?(services, state, wallet_ready?) do
    wallet_ready? and is_map(services.basenames_config) and
      services.basenames_config.payment_recipient not in [nil, ""] and state.valid? and
      state.available? == true and not state.reserved?
  end

  defp allowance_remaining(%{allowance: %{free_mints_remaining: value}}), do: value
  defp allowance_remaining(_services), do: 0

  defp ens_parent_name(%{basenames_config: %{ens_parent_name: value}}) when is_binary(value),
    do: value

  defp ens_parent_name(_services), do: "regent.eth"

  defp basenames_price_wei(%{basenames_config: %{price_wei: value}}), do: value
  defp basenames_price_wei(_services), do: nil

  defp basenames_payment_recipient(%{basenames_config: %{payment_recipient: value}}), do: value
  defp basenames_payment_recipient(_services), do: nil

  defp availability_badge_label(%{reserved?: true}), do: "Reserved"
  defp availability_badge_label(%{available?: true}), do: "Available"
  defp availability_badge_label(%{available?: false}), do: "Taken"
  defp availability_badge_label(_state), do: "Checking"

  defp availability_badge_class(%{reserved?: true}),
    do: "rounded-full border border-[color:#a6574f] px-3 py-1 text-[color:#a6574f]"

  defp availability_badge_class(%{available?: true}),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-[color:var(--foreground)]"

  defp availability_badge_class(%{available?: false}),
    do: "rounded-full border border-[color:#a6574f] px-3 py-1 text-[color:#a6574f]"

  defp availability_badge_class(_state),
    do:
      "rounded-full border border-[color:var(--border)] px-3 py-1 text-[color:var(--muted-foreground)]"

  defp notice_class(:success) do
    "border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] bg-[color:color-mix(in_oklch,var(--positive)_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp notice_class(:error) do
    "border-[color:#a6574f] bg-[color:color-mix(in_oklch,#a6574f_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp notice_class(_tone) do
    "border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] text-[color:var(--foreground)]"
  end

  defp total_eligible_tokens(formation) do
    length(formation.collections.animata1) + length(formation.collections.animata2) +
      length(formation.collections.animata_pass)
  end

  defp billing_value(%{connected: true}), do: "Active"
  defp billing_value(%{status: "checkout_open"}), do: "Pending"
  defp billing_value(_billing), do: "Not active"

  defp formation_claim_options(claims) do
    Enum.map(claims, fn claim ->
      {claim.ens_fqdn || "#{claim.label}.regent.eth", claim.label}
    end)
  end

  defp selected_hostname(nil), do: "Choose a claimed name"
  defp selected_hostname(claimed_label), do: "#{claimed_label}.regents.sh"

  defp selected_identity(_claims, nil), do: "No claimed name yet"

  defp selected_identity(claims, claimed_label) do
    claims
    |> Enum.find(&(&1.label == claimed_label))
    |> then(fn
      nil -> "Choose a claimed name"
      claim -> claim.ens_fqdn || "#{claim.label}.regent.eth"
    end)
  end

  defp active_formation?(formation) do
    Enum.any?(formation.active_formations, &(&1.status in ["queued", "running"]))
  end

  defp launch_step_label(nil), do: "Starting your company"

  defp launch_step_label(formation) do
    case formation.current_step do
      "reserve_claim" -> "Saving your company name"
      "create_sprite" -> "Starting your company"
      "bootstrap_sprite" -> "Preparing your company"
      "bootstrap_workspace" -> "Building your company workspace"
      "verify_runtime" -> "Checking your company"
      "activate_subdomain" -> "Opening your public page"
      "finalize" -> "Opening the dashboard"
      _ -> "Preparing your company"
    end
  end

  defp launch_step_copy(nil), do: "We’re preparing the company dashboard."

  defp launch_step_copy(formation) do
    case formation.current_step do
      "verify_runtime" -> "We’re checking that the company is responding before opening it."
      "activate_subdomain" -> "Your public page is being opened now."
      "finalize" -> "Everything is almost ready. The dashboard comes next."
      _ -> "We’re working through the setup steps now."
    end
  end

  defp launch_progress_step_key("bootstrap_sprite"), do: "create_sprite"
  defp launch_progress_step_key(step), do: step

  def billing_stage_ready?(%{authenticated: true, available_claims: claims})
      when is_list(claims) and claims != [] do
    true
  end

  def billing_stage_ready?(_formation), do: false

  def billing_blocker_copy(%{authenticated: false}),
    do: "Sign in first, then claim a name before adding billing."

  def billing_blocker_copy(%{readiness: %{blocked_step: %{message: message}}})
      when is_binary(message),
      do: message

  def billing_blocker_copy(%{available_claims: []}),
    do: "Claim a name first, then come back here to add billing."

  def billing_blocker_copy(_formation),
    do: "Add billing once a claimed name is ready."

  def billing_next_step_label(%{authenticated: false}), do: "Go to access"

  def billing_next_step_label(%{readiness: %{blocked_step: %{action_label: label}}})
      when is_binary(label),
      do: label

  def billing_next_step_label(%{available_claims: []}), do: "Go to identity"
  def billing_next_step_label(_formation), do: "Continue"

  def billing_next_step_path(%{authenticated: false}), do: "/app/access"

  def billing_next_step_path(%{readiness: %{blocked_step: %{action_path: path}}})
      when is_binary(path),
      do: path

  def billing_next_step_path(%{available_claims: []}), do: "/app/identity"
  def billing_next_step_path(_formation), do: "/app/formation"

  def formation_stage_ready?(%{
        authenticated: true,
        eligible: true,
        available_claims: claims,
        billing_account: %{connected: true}
      })
      when is_list(claims) and claims != [] do
    true
  end

  def formation_stage_ready?(_formation), do: false

  def formation_blocker_copy(%{authenticated: false}),
    do: "Sign in first so this wallet can be checked."

  def formation_blocker_copy(%{readiness: %{ready: true}}),
    do: "Everything is ready. You can open the company now."

  def formation_blocker_copy(%{readiness: %{blocked_step: %{message: message}}})
      when is_binary(message),
      do: message

  def formation_blocker_copy(%{eligible: false}),
    do: "This wallet still needs a qualifying pass."

  def formation_blocker_copy(%{available_claims: []}),
    do: "Claim a name first, then come back here to open the company."

  def formation_blocker_copy(%{billing_account: %{connected: false}}),
    do: "Add billing first, then open the company."

  def formation_blocker_copy(_formation),
    do: "The company is not ready yet."

  def formation_next_step_label(%{authenticated: false}), do: "Go to access"

  def formation_next_step_label(%{readiness: %{ready: true}}), do: "Open company"

  def formation_next_step_label(%{readiness: %{blocked_step: %{action_label: label}}})
      when is_binary(label),
      do: label

  def formation_next_step_label(%{eligible: false}), do: "Go to access"
  def formation_next_step_label(%{available_claims: []}), do: "Go to identity"
  def formation_next_step_label(%{billing_account: %{connected: false}}), do: "Go to billing"
  def formation_next_step_label(_formation), do: "Open company"

  def formation_next_step_path(%{authenticated: false}), do: "/app/access"

  def formation_next_step_path(%{readiness: %{ready: true}}), do: "/app/formation"

  def formation_next_step_path(%{readiness: %{blocked_step: %{action_path: path}}})
      when is_binary(path),
      do: path

  def formation_next_step_path(%{eligible: false}), do: "/app/access"
  def formation_next_step_path(%{available_claims: []}), do: "/app/identity"
  def formation_next_step_path(%{billing_account: %{connected: false}}), do: "/app/billing"
  def formation_next_step_path(_formation), do: "/app/formation"

  def provisioning_not_found_copy,
    do: "This link no longer matches an active company opening."

  def identity_blocker_copy(false),
    do: "Sign in first so the wallet can be checked."

  def identity_blocker_copy(true),
    do: "Enter a name to see whether it can be claimed."

  defp status_badge_class("active"),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]"

  defp status_badge_class("succeeded"),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]"

  defp status_badge_class("ready"),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]"

  defp status_badge_class(_status),
    do:
      "rounded-full border border-[color:var(--border)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]"

  defp format_usd_cents(cents) when is_integer(cents) do
    "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_usd_cents(_cents), do: "$0.00"

  defp format_credit_expiry(nil), do: "an upcoming date"

  defp format_credit_expiry(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%b %-d, %Y")
      _ -> value
    end
  end

  defp opensea_mark(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      class="h-5 w-5 text-[color:var(--foreground)]"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="12" r="9.25"></circle>
      <path d="M9.4 16.8c1.2-.6 2.35-.9 3.45-.9 1.25 0 2.32.28 3.2.84"></path>
      <path d="M11.7 6.1l2.8 7.3-5.8-.35 3-6.95Z"></path>
      <path d="M11.9 13.1v4.2"></path>
      <path d="M8.7 17.2h6.4"></path>
    </svg>
    """
  end

  defp billing_back_path(nil), do: "/app/billing"
  defp billing_back_path(claimed_label), do: "/app/billing?claimedLabel=#{claimed_label}"
end
