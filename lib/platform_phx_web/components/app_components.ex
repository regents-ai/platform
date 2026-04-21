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
    ~H"""
    <div class="space-y-6">
      <div class="grid gap-4 md:grid-cols-3">
        <.metric_tile
          label="Wallet"
          value={if(@services.authenticated, do: "Signed in", else: "Not signed in")}
          copy="Sign in to check your pass access."
        />
        <.metric_tile
          label="Pass access"
          value={if(eligible_services?(@services), do: "Ready", else: "Not ready")}
          copy="You need a qualifying pass before the company can be opened."
        />
        <.metric_tile
          label="Claimable names"
          value={Integer.to_string(length(@services.available_claims))}
          copy="Unused names tied to this wallet."
        />
      </div>

      <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
          Access
        </p>
        <h2 class="mt-3 font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
          Check whether this wallet can open a company.
        </h2>
        <p class="mt-4 max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
          Start here to sign in, confirm pass access, and redeem a pass when you need one before moving on to a name and billing.
        </p>

        <div class="mt-6 grid gap-4 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
          <section
            id="app-access-redeem"
            phx-hook="DashboardRedeem"
            data-dashboard-config={@redeem_island_config}
            class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5"
          >
            <div class="space-y-3">
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Redeem a pass
              </h3>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Use this when you need to turn a qualifying pass into company access for this wallet.
              </p>
            </div>

            <%= if @services.holdings_notice do %>
              <.inline_notice notice={@services.holdings_notice} class="mt-4" />
            <% end %>

            <div class="mt-5 grid gap-4 sm:grid-cols-2">
              <.metric_tile
                label="Animata I"
                value={Integer.to_string(length(@services.holdings.animata1))}
                copy="Held by this wallet"
              />
              <.metric_tile
                label="Animata II"
                value={Integer.to_string(length(@services.holdings.animata2))}
                copy="Held by this wallet"
              />
              <.metric_tile
                label="Regents Club"
                value={Integer.to_string(length(@services.holdings.animata_pass))}
                copy="Passes already in the wallet"
              />
              <.metric_tile
                label="Snapshot claims"
                value={Integer.to_string(allowance_remaining(@services))}
                copy="Unused name claims left"
              />
            </div>

            <div class="mt-5 rounded-[1.3rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-end">
                <label class="flex-1 space-y-2">
                  <span class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Source collection
                  </span>
                  <select
                    data-dashboard-redeem-source
                    class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
                  >
                    <option value="ANIMATA1">Animata I</option>
                    <option value="ANIMATA2">Animata II</option>
                  </select>
                </label>

                <label class="flex-1 space-y-2">
                  <span class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Token ID
                  </span>
                  <input
                    data-dashboard-redeem-token-id
                    type="text"
                    inputmode="numeric"
                    placeholder="123"
                    class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
                  />
                </label>
              </div>

              <div class="mt-4 flex flex-wrap gap-3">
                <button
                  type="button"
                  data-dashboard-redeem-approve-nft
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                >
                  Approve NFT
                </button>
                <button
                  type="button"
                  data-dashboard-redeem-approve-usdc
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                >
                  Approve payment
                </button>
                <button
                  type="button"
                  data-dashboard-redeem-start
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                >
                  Redeem
                </button>
                <button
                  type="button"
                  data-dashboard-redeem-claim
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                >
                  Claim unlocked pass
                </button>
              </div>

              <p data-dashboard-redeem-notice class="mt-4 hidden text-sm leading-6"></p>
            </div>
          </section>

          <section class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                  What unlocks the next step
                </h3>
                <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Once this wallet is signed in and holds a qualifying pass, the app will send you forward to claim or use a name.
                </p>
              </div>
              <a
                href="https://opensea.io/collection/regents-club"
                target="_blank"
                rel="noreferrer"
                class="inline-flex items-center gap-2 rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                <.opensea_mark />
                <span>OpenSea</span>
              </a>
            </div>

            <div class="mt-5 space-y-3">
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Qualifying holdings
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Collection I, Collection II, or Regents Club all unlock the path.
                </p>
              </div>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Current blocker
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  {access_blocker_copy(@services)}
                </p>
              </div>
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Next after this
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  Claim or choose the name you want to use for the company.
                </p>
              </div>
            </div>
          </section>
        </div>
      </section>
    </div>
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
    ~H"""
    <section
      id="app-identity-shell"
      phx-hook="DashboardNameClaim"
      data-dashboard-config={@claim_island_config}
      class="space-y-6"
    >
      <div class="grid gap-4 md:grid-cols-3">
        <.metric_tile
          label="Unused names"
          value={Integer.to_string(length(@services.available_claims))}
          copy="Already claimed and ready to use."
        />
        <.metric_tile
          label="Snapshot claims"
          value={Integer.to_string(allowance_remaining(@services))}
          copy="Still open to this wallet."
        />
        <.metric_tile
          label="Recent names"
          value={Integer.to_string(length(@services.recent_names))}
          copy="Latest names claimed across the network."
        />
      </div>

      <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
          Identity
        </p>
        <h2 class="mt-3 font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
          Claim the name you want to use for the company.
        </h2>
        <p class="mt-4 max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
          Choose a name, check whether it is open, and finish the wallet step when you are ready. Once a name is ready, the app will send you to billing.
        </p>

        <div class="mt-6 grid gap-4 lg:grid-cols-2">
          <div class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Current blocker
            </p>
            <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
              {identity_blocker_copy(@wallet_ready?)}
            </p>
          </div>

          <div class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              What you can do now
            </p>
            <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
              Use the snapshot claim for wallet-held names or the public claim for a paid name. The button stays off until the name is valid.
            </p>
          </div>
        </div>

        <%= if @services.allowance_notice do %>
          <.inline_notice notice={@services.allowance_notice} class="mt-5" />
        <% end %>

        <div class="mt-6 grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Names on this wallet
              </h3>
              <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                Already claimed names show up here. Unused names can go straight into the company flow.
              </p>
            </div>

            <div class="grid gap-3">
              <%= if @services.owned_names == [] do %>
                <div class="rounded-[1.2rem] border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                  No claimed names yet. Claim one and it will appear here.
                </div>
              <% else %>
                <%= for name <- @services.owned_names do %>
                  <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-4">
                    <p class="font-display text-lg text-[color:var(--foreground)]">
                      {name.ens_fqdn || name.fqdn}
                    </p>
                    <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                      {if name.is_in_use, do: "Already used by a company.", else: "Ready to use."}
                    </p>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Recent names
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <%= if @services.recent_names == [] do %>
                  <span class="text-sm text-[color:var(--muted-foreground)]">
                    No recent names yet. New claims will appear here.
                  </span>
                <% else %>
                  <%= for name <- @services.recent_names do %>
                    <span class="rounded-full border border-[color:var(--border)] px-3 py-1.5 text-sm text-[color:var(--foreground)]">
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
              class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5"
            >
              <div class="space-y-3">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Snapshot claim
                </p>
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
                  class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
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
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
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
              class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5"
            >
              <div class="space-y-3">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Public claim
                </p>
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
                  class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
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
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] disabled:cursor-not-allowed disabled:opacity-60"
                  disabled={!can_paid_claim?(@services, @phase2_state, @wallet_ready?)}
                >
                  Pay and claim
                </button>
              </div>
            </.form>
          </section>
        </div>

        <p data-dashboard-claim-notice class="hidden text-sm leading-6"></p>
      </section>
    </section>
    """
  end

  attr :formation, :map, required: true
  attr :selected_claimed_label, :string, default: nil
  attr :setup_form, :map, required: true
  attr :billing_notice, :map, default: nil

  def billing_stage(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid gap-4 md:grid-cols-3">
        <.metric_tile
          label="Passes found"
          value={Integer.to_string(total_eligible_tokens(@formation))}
          copy="Across all qualifying collections."
        />
        <.metric_tile
          label="Unused names"
          value={Integer.to_string(length(@formation.available_claims))}
          copy="Names ready to use."
        />
        <.metric_tile
          label="Billing"
          value={billing_value(@formation.billing_account)}
          copy="This unlocks company creation."
        />
      </div>

      <%= if @billing_notice do %>
        <.inline_notice notice={@billing_notice} />
      <% end %>

      <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
          Billing
        </p>
        <h2 class="mt-3 font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
          Add billing for the company you want to open.
        </h2>
        <p class="mt-4 max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
          Pick the name you want to carry forward, then add billing so the company can be opened in the next step.
        </p>

        <div class="mt-6 grid gap-4 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
          <section class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <.form
              for={@setup_form}
              id="app-billing-form"
              phx-change="change_selected_claim"
              class="space-y-5"
            >
              <label class="space-y-2">
                <span class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Company name
                </span>
                <.input
                  field={@setup_form[:claimed_label]}
                  type="select"
                  options={formation_claim_options(@formation.available_claims)}
                  class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
                />
              </label>

              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                <p>
                  Public page:
                  <span class="text-[color:var(--foreground)]">
                    {selected_hostname(@selected_claimed_label)}
                  </span>
                </p>
                <p class="mt-2">
                  Claimed name:
                  <span class="text-[color:var(--foreground)]">
                    {selected_identity(@formation.available_claims, @selected_claimed_label)}
                  </span>
                </p>
              </div>

              <%= if @formation.billing_account.connected do %>
                <.inline_notice notice={
                  %{
                    tone: :success,
                    message: "Billing is active. You can continue to company creation."
                  }
                } />
              <% else %>
                <.inline_notice notice={
                  %{tone: :info, message: "Finish billing setup to unlock company creation."}
                } />
              <% end %>

              <div class="flex flex-wrap justify-end gap-3">
                <%= if @formation.billing_account.connected do %>
                  <.link
                    navigate={~p"/app/formation?claimedLabel=#{@selected_claimed_label}"}
                    class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                  >
                    Continue
                  </.link>
                <% else %>
                  <button
                    type="button"
                    phx-click="start_billing_setup"
                    class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                  >
                    Set up billing
                  </button>
                <% end %>
              </div>
            </.form>
          </section>

          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Billing status
              </p>
              <p class="mt-2 font-display text-2xl text-[color:var(--foreground)]">
                {billing_value(@formation.billing_account)}
              </p>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Credit balance
              </p>
              <p class="mt-2 font-display text-2xl text-[color:var(--foreground)]">
                {format_usd_cents(@formation.billing_account.runtime_credit_balance_usd_cents)}
              </p>
            </div>

            <%= if @formation.billing_account.welcome_credit do %>
              <div class="rounded-[1.2rem] border border-[color:color-mix(in_oklch,var(--positive)_45%,var(--border)_55%)] bg-[color:color-mix(in_oklch,var(--positive)_9%,transparent)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Launch credit
                </p>
                <p class="mt-2 font-display text-2xl text-[color:var(--foreground)]">
                  {format_usd_cents(@formation.billing_account.welcome_credit.amount_usd_cents)}
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Credit for company usage is already waiting and expires on {format_credit_expiry(
                    @formation.billing_account.welcome_credit.expires_at
                  )}.
                </p>
              </div>
            <% end %>
          </section>
        </div>
      </section>
    </div>
    """
  end

  attr :formation, :map, required: true
  attr :selected_claimed_label, :string, default: nil
  attr :setup_form, :map, required: true

  def formation_stage(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid gap-4 md:grid-cols-4">
        <.metric_tile
          label="Passes found"
          value={Integer.to_string(total_eligible_tokens(@formation))}
          copy="Across all qualifying collections."
        />
        <.metric_tile
          label="Unused names"
          value={Integer.to_string(length(@formation.available_claims))}
          copy="Still ready for a new company."
        />
        <.metric_tile
          label="Billing"
          value={billing_value(@formation.billing_account)}
          copy="Needed before launch."
        />
        <.metric_tile
          label="Companies"
          value={Integer.to_string(length(@formation.owned_companies))}
          copy="Already opened on this account."
        />
      </div>

      <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
          Formation
        </p>
        <h2 class="mt-3 font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
          Open your company.
        </h2>
        <p class="mt-4 max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
          You need a claimed name, active billing, and a wallet that can open companies. Once those are ready, open the company here and you will move to the progress page.
        </p>

        <div class="mt-6 grid gap-4 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
          <section class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <.form
              for={@setup_form}
              id="app-formation-form"
              phx-change="change_selected_claim"
              class="space-y-5"
            >
              <label class="space-y-2">
                <span class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Claimed name
                </span>
                <.input
                  field={@setup_form[:claimed_label]}
                  type="select"
                  options={formation_claim_options(@formation.available_claims)}
                  class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
                />
              </label>

              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                <p>
                  Public page:
                  <span class="text-[color:var(--foreground)]">
                    {selected_hostname(@selected_claimed_label)}
                  </span>
                </p>
                <p class="mt-2">
                  Claimed name:
                  <span class="text-[color:var(--foreground)]">
                    {selected_identity(@formation.available_claims, @selected_claimed_label)}
                  </span>
                </p>
              </div>

              <%= if @formation.billing_account.connected do %>
                <.inline_notice notice={
                  %{tone: :success, message: "Billing is active. You can open the company now."}
                } />
                <div class="flex flex-wrap justify-end gap-3">
                  <button
                    type="button"
                    phx-click="start_company"
                    class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                  >
                    Open company
                  </button>
                </div>
              <% else %>
                <.inline_notice notice={
                  %{
                    tone: :info,
                    message: "Go back one step and finish billing before opening the company."
                  }
                } />
                <div class="flex flex-wrap justify-end gap-3">
                  <.link
                    navigate={billing_back_path(@selected_claimed_label)}
                    class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                  >
                    Back to billing
                  </.link>
                </div>
              <% end %>
            </.form>
          </section>

          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Names ready to use
              </p>
              <div class="mt-3 grid gap-3">
                <%= for claim <- @formation.available_claims do %>
                  <div class="rounded-[1rem] border border-[color:var(--border)] px-3 py-3 text-sm text-[color:var(--foreground)]">
                    {claim.ens_fqdn || "#{claim.label}.regent.eth"}
                  </div>
                <% end %>
                <%= if @formation.available_claims == [] do %>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    No claimed names are ready yet.
                  </p>
                <% end %>
              </div>
            </div>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Active company openings
              </p>
              <div class="mt-3 grid gap-3">
                <%= if @formation.active_formations == [] do %>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    No company is opening right now.
                  </p>
                <% else %>
                  <%= for formation <- @formation.active_formations do %>
                    <div class="rounded-[1rem] border border-[color:var(--border)] px-3 py-3">
                      <div class="flex items-center justify-between gap-3">
                        <p class="text-sm text-[color:var(--foreground)]">
                          {formation.claimed_label || "Opening company"}
                        </p>
                        <span class={status_badge_class(formation.status)}>{formation.status}</span>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </section>
    </div>
    """
  end

  attr :company, :map, required: true
  attr :formation, :map, default: nil

  def provisioning_stage(assigns) do
    ~H"""
    <section
      id="app-provisioning-shell"
      phx-hook="LaunchProgress"
      class="space-y-6"
    >
      <section class="overflow-hidden rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_22%,var(--border)_78%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_95%,var(--background)_5%),color-mix(in_oklch,var(--background)_90%,var(--card)_10%))] px-5 py-6 shadow-[0_28px_90px_-56px_color-mix(in_oklch,var(--brand-ink)_35%,transparent)] sm:px-6">
        <div class="grid gap-5 lg:grid-cols-[minmax(0,1.25fr)_minmax(18rem,0.75fr)]">
          <div class="pp-launch-progress-copy space-y-4">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Opening now
              </p>
              <h2 class="font-display text-[clamp(2rem,4vw,3rem)] leading-[0.92] text-[color:var(--foreground)]">
                We’re opening {@company.subdomain.hostname}
              </h2>
              <p class="max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                Stay here for a moment. As soon as setup finishes, this page will move you into the company dashboard automatically.
              </p>
            </div>

            <div class="grid gap-3 sm:grid-cols-3">
              <div class="pp-launch-progress-card rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                <p class="text-[10px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Company
                </p>
                <p class="mt-2 font-display text-[1.05rem] text-[color:var(--foreground)]">
                  {@company.name}
                </p>
              </div>

              <div class="pp-launch-progress-card rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                <p class="text-[10px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Current step
                </p>
                <p class="mt-2 font-display text-[1.05rem] text-[color:var(--foreground)]">
                  {launch_step_label(@formation)}
                </p>
              </div>

              <div class="pp-launch-progress-card rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
                <p class="text-[10px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                  Next
                </p>
                <p class="mt-2 text-sm leading-6 text-[color:var(--foreground)]">
                  {launch_step_copy(@formation)}
                </p>
              </div>
            </div>
          </div>

          <div class="pp-launch-progress-card rounded-[1.5rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] p-5">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              What happens next
            </p>

            <div class="mt-4 grid gap-3">
              <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="font-display text-[1rem] text-[color:var(--foreground)]">1. Finish setup</p>
                <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  We work through the final opening steps for you.
                </p>
              </div>

              <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                  2. Open the dashboard
                </p>
                <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Once setup finishes, you land on the place where you can control the company.
                </p>
              </div>

              <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
                <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                  3. Choose the next lane
                </p>
                <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  From there you can step into Techtree or Autolaunch when you are ready.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </section>
    """
  end

  attr :formation, :map, required: true
  attr :usage, :map, required: true
  attr :current_human, :map, required: true
  attr :holdings, :map, required: true
  attr :formation_token_cards, :map, required: true
  attr :shader_options, :list, required: true
  attr :avatar_save_notice, :map, default: nil

  def dashboard_stage(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid gap-4 md:grid-cols-5">
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
          copy="Sprites spend already recorded for this account."
        />
        <.metric_tile
          label="Model spend"
          value={format_usd_cents(@usage.llm_spend_usd_cents)}
          copy="Model usage already recorded for this account."
        />
        <.metric_tile
          label="Opened companies"
          value={Integer.to_string(length(@formation.owned_companies))}
          copy="Companies tied to this account."
        />
      </div>

      <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Dashboard
            </p>
            <h2 class="mt-3 font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
              Control the hosted company from here.
            </h2>
            <p class="mt-4 max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
              This is the control surface for the company you opened on Regents. Review billing, check company status, pick the saved public avatar, and pause or resume a company when needed.
            </p>
          </div>
          <.link
            navigate={~p"/app/formation"}
            class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
          >
            Open another company
          </.link>
        </div>

        <div
          id="app-dashboard-avatar-creator"
          class="mt-6 grid gap-4 xl:grid-cols-[minmax(0,0.82fr)_minmax(0,1.18fr)]"
        >
          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="space-y-2">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Agent Avatar Creator
              </p>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Choose the saved look for your public company pages.
              </h3>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Pick an owned collection avatar or save one of the shader looks below. Regents Club keeps the gold border. Saved shader looks do not.
              </p>
            </div>

            <%= if @avatar_save_notice do %>
              <.inline_notice notice={@avatar_save_notice} />
            <% end %>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
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
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Gold border rule
              </p>
              <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                The gold border only appears when the saved avatar is a Regents Club choice. Shader looks and other collection picks stay on the standard frame.
              </p>
            </div>
          </section>

          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
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
                        class={
                          avatar_choice_button_class(@current_human.avatar, "animata1", token_id)
                        }
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
                    <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
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
                        class={
                          avatar_choice_button_class(@current_human.avatar, "animata2", token_id)
                        }
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
                  <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
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
                  <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Shader looks
                  </p>
                  <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                    Save one of these shader looks as your account-level avatar.
                  </p>
                </div>

                <.link
                  navigate={~p"/shader"}
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
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
        </div>

        <div class="mt-6 grid gap-4 xl:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)]">
          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h3 class="font-display text-2xl text-[color:var(--foreground)]">Companies</h3>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Use this list to review status and control each hosted company.
                </p>
              </div>
            </div>

            <div class="space-y-3">
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
                        class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        Open public page
                      </a>
                      <%= if company.desired_runtime_state == "paused" do %>
                        <button
                          type="button"
                          phx-click="resume_company"
                          phx-value-slug={company.slug}
                          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                        >
                          Resume company
                        </button>
                      <% else %>
                        <button
                          type="button"
                          phx-click="pause_company"
                          phx-value-slug={company.slug}
                          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
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

          <section class="space-y-4 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
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
              <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Opening now
                </p>
                <div class="mt-3 space-y-3">
                  <%= for formation <- @formation.active_formations do %>
                    <.link
                      navigate={~p"/app/provisioning/#{formation.id}"}
                      class="flex items-center justify-between gap-3 rounded-[1rem] border border-[color:var(--border)] px-3 py-3 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                    >
                      <span>{formation.claimed_label || "Opening company"}</span>
                      <span aria-hidden="true">→</span>
                    </.link>
                  <% end %>
                </div>
              </div>
            <% end %>

            <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Next steps
              </p>
              <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                When the hosted company is ready, move outward into the work lanes below.
              </p>
            </div>

            <.sister_project_cards />
          </section>
        </div>
      </section>
    </div>
    """
  end

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
      "bootstrap_paperclip" -> "Connecting company tools"
      "create_company" -> "Building your company home"
      "create_hermes" -> "Getting the company assistant ready"
      "create_checkpoint" -> "Saving your first restore point"
      "activate_subdomain" -> "Opening your public page"
      "finalize" -> "Opening the dashboard"
      _ -> "Preparing your company"
    end
  end

  defp launch_step_copy(nil), do: "We’re preparing the company dashboard."

  defp launch_step_copy(formation) do
    case formation.current_step do
      "activate_subdomain" -> "Your public page is being opened now."
      "finalize" -> "Everything is almost ready. The dashboard comes next."
      _ -> "We’re working through the setup steps now."
    end
  end

  def billing_stage_ready?(%{authenticated: true, available_claims: claims})
      when is_list(claims) and claims != [] do
    true
  end

  def billing_stage_ready?(_formation), do: false

  def billing_blocker_copy(%{authenticated: false}),
    do: "Sign in first, then claim a name before adding billing."

  def billing_blocker_copy(%{available_claims: []}),
    do: "Claim a name first, then come back here to add billing."

  def billing_blocker_copy(_formation),
    do: "Add billing once a claimed name is ready."

  def billing_next_step_label(%{authenticated: false}), do: "Go to access"
  def billing_next_step_label(%{available_claims: []}), do: "Go to identity"
  def billing_next_step_label(_formation), do: "Continue"

  def billing_next_step_path(%{authenticated: false}), do: "/app/access"
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

  def formation_blocker_copy(%{eligible: false}),
    do: "This wallet still needs a qualifying pass."

  def formation_blocker_copy(%{available_claims: []}),
    do: "Claim a name first, then come back here to open the company."

  def formation_blocker_copy(%{billing_account: %{connected: false}}),
    do: "Add billing first, then open the company."

  def formation_blocker_copy(_formation),
    do: "The company is not ready yet."

  def formation_next_step_label(%{authenticated: false}), do: "Go to access"
  def formation_next_step_label(%{eligible: false}), do: "Go to access"
  def formation_next_step_label(%{available_claims: []}), do: "Go to identity"
  def formation_next_step_label(%{billing_account: %{connected: false}}), do: "Go to billing"
  def formation_next_step_label(_formation), do: "Open company"

  def formation_next_step_path(%{authenticated: false}), do: "/app/access"
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
