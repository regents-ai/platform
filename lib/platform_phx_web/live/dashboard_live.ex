defmodule PlatformPhxWeb.DashboardLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Accounts
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.Dashboard
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhx.TokenCardManifest

  @refresh_ms 2_500

  @impl true
  def mount(_params, session, socket) do
    current_human = Accounts.get_human(session["current_human_id"])
    page = dashboard_page(socket.assigns.live_action)

    socket =
      socket
      |> assign(page)
      |> assign(:current_human, current_human)
      |> assign(:claim_island_config, Jason.encode!(claim_island_config()))
      |> assign(:redeem_island_config, Jason.encode!(redeem_island_config()))
      |> assign(:wallet_ready?, wallet_ready?())
      |> assign(:services, empty_services())
      |> assign(:formation_data, nil)
      |> assign(:formation_notice, nil)
      |> assign(:formation_stage, :gate)
      |> assign(:selected_claimed_label, nil)
      |> assign(:requested_claimed_label, nil)
      |> assign(:billing_return_state, nil)
      |> assign(:launching_slug, nil)
      |> assign(:formation_token_cards, %{})
      |> assign(:phase1_label, "")
      |> assign(:phase2_label, "")
      |> assign(:phase1_state, Dashboard.name_claim_state("", nil, nil))
      |> assign(:phase2_state, Dashboard.name_claim_state("", nil, nil))
      |> assign_forms()
      |> load_page_payload()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    stage = if params["stage"] == "setup", do: :setup, else: :gate
    requested_claimed_label = normalize_claimed_label(params["claimedLabel"])
    launching_slug = normalize_claimed_label(params["launch"])
    billing_return_state = normalize_billing_return_state(params["billing"])

    socket =
      socket
      |> assign(:formation_stage, stage)
      |> assign(:requested_claimed_label, requested_claimed_label)
      |> assign(:launching_slug, launching_slug)
      |> assign(:billing_return_state, billing_return_state)
      |> sync_selected_claim()
      |> maybe_put_billing_return_flash()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_phase1_label", %{"phase1_claim" => %{"label" => label}}, socket) do
    {:noreply, socket |> assign(:phase1_label, label) |> refresh_name_claim_states()}
  end

  @impl true
  def handle_event("change_phase2_label", %{"phase2_claim" => %{"label" => label}}, socket) do
    {:noreply, socket |> assign(:phase2_label, label) |> refresh_name_claim_states()}
  end

  @impl true
  def handle_event("continue_formation", _params, socket) do
    {:noreply, push_patch(socket, to: formation_path(socket, :setup))}
  end

  @impl true
  def handle_event(
        "change_selected_claim",
        %{"formation_setup" => %{"claimed_label" => claimed_label}},
        socket
      ) do
    {:noreply, assign(socket, :selected_claimed_label, normalize_claimed_label(claimed_label))}
  end

  @impl true
  def handle_event("start_billing_setup", _params, socket) do
    case Formation.start_billing_setup_checkout(socket.assigns.current_human, %{
           "claimedLabel" => socket.assigns.selected_claimed_label
         }) do
      {:ok, %{checkout_url: checkout_url}} when is_binary(checkout_url) ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("start_company", _params, socket) do
    claimed_label = socket.assigns.selected_claimed_label

    case Formation.create_company(socket.assigns.current_human, %{"claimedLabel" => claimed_label}) do
      {:accepted, payload} ->
        launching_slug = get_in(payload, [:agent, :slug])
        launch_path = formation_path(socket, :setup, launching_slug)

        {:noreply,
         socket
         |> assign(:launching_slug, launching_slug)
         |> put_flash(:info, "Your company is launching now.")
         |> load_formation_payload()
         |> push_patch(to: launch_path)}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("refresh_formation", _params, socket) do
    {:noreply, load_formation_payload(socket)}
  end

  @impl true
  def handle_info(:refresh_formation_payload, socket) do
    {:noreply, load_formation_payload(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav={@active_nav}
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-dashboard-shell"
        class="pp-dashboard-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="pp-voxel-background pp-voxel-background--dashboard" aria-hidden="true">
          <div
            id="dashboard-voxel-background"
            class="pp-voxel-background-canvas"
            phx-hook="VoxelBackground"
            data-voxel-background="dashboard"
          >
          </div>
        </div>

        <div class="pp-route-stage">
          <section class="pp-route-grid" data-dashboard-block>
            <article
              id={@console_id}
              class="pp-route-panel pp-product-panel pp-route-panel-span space-y-6"
            >
              <div class="space-y-3">
                <p class="pp-home-kicker">{@console_eyebrow}</p>
                <h2 class="pp-route-panel-title max-w-[18ch]">
                  {@console_title}
                </h2>
                <p class="pp-panel-copy max-w-[40rem]">
                  {@console_copy}
                </p>
              </div>

              <%= if @active_nav == "services" do %>
                <.services_view
                  services={@services}
                  phase1_form={@phase1_form}
                  phase2_form={@phase2_form}
                  phase1_state={@phase1_state}
                  phase2_state={@phase2_state}
                  claim_island_config={@claim_island_config}
                  redeem_island_config={@redeem_island_config}
                  wallet_ready?={@wallet_ready?}
                />
              <% else %>
                <.agent_formation_view
                  formation={@formation_data}
                  formation_token_cards={@formation_token_cards}
                  notice={@formation_notice}
                  stage={@formation_stage}
                  selected_claimed_label={@selected_claimed_label}
                  launching_slug={@launching_slug}
                  wallet_ready?={@wallet_ready?}
                />
              <% end %>
            </article>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :services, :map, required: true
  attr :phase1_form, :map, required: true
  attr :phase2_form, :map, required: true
  attr :phase1_state, :map, required: true
  attr :phase2_state, :map, required: true
  attr :claim_island_config, :string, required: true
  attr :redeem_island_config, :string, required: true
  attr :wallet_ready?, :boolean, required: true

  defp services_view(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <section
          id="services-redeem"
          phx-hook="DashboardRedeem"
          data-dashboard-config={@redeem_island_config}
          class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5"
        >
          <div class="space-y-3">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Redeem
            </p>
            <h3 class="font-display text-2xl text-[color:var(--foreground)]">
              Redeem an Animata pass for REGENT
            </h3>
            <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
              This redemption still finishes inside your wallet, but the holdings, supply, and account view now load here with the rest of the page.
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
              copy="Animated passes already in the wallet"
            />
            <.metric_tile
              label="Free claims"
              value={Integer.to_string(allowance_remaining(@services))}
              copy="Unused names still available to this wallet"
            />
          </div>

          <div class="mt-5 space-y-4">
            <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
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
                  Approve 80 USDC
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
                  Claim unlocked REGENT
                </button>
              </div>

              <div class="mt-4 flex flex-wrap gap-3 text-sm text-[color:var(--muted-foreground)]">
                <p>
                  Unlocked now:
                  <span data-dashboard-redeem-claimable class="text-[color:var(--foreground)]">
                    --
                  </span>
                </p>
                <p>
                  Still streaming:
                  <span data-dashboard-redeem-remaining class="text-[color:var(--foreground)]">
                    --
                  </span>
                </p>
              </div>

              <p data-dashboard-redeem-notice class="mt-4 hidden text-sm leading-6"></p>
            </div>

            <div class="grid gap-3 sm:grid-cols-3">
              <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Animata I tokens
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <%= if @services.holdings.animata1 == [] do %>
                    <span class="text-sm text-[color:var(--muted-foreground)]">None found.</span>
                  <% else %>
                    <%= for token_id <- @services.holdings.animata1 do %>
                      <a
                        href={opensea_item_url(:animata1, token_id)}
                        target="_blank"
                        rel="noreferrer"
                        class="rounded-full border border-[color:var(--border)] px-3 py-1.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        #{token_id}
                      </a>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Regents Club passes
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <%= if @services.holdings.animata_pass == [] do %>
                    <span class="text-sm text-[color:var(--muted-foreground)]">None found.</span>
                  <% else %>
                    <%= for token_id <- @services.holdings.animata_pass do %>
                      <.link
                        navigate={~p"/cards/regents-club/#{token_id}"}
                        class="rounded-full border border-[color:var(--border)] px-3 py-1.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        #{token_id}
                      </.link>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                  Animata II tokens
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <%= if @services.holdings.animata2 == [] do %>
                    <span class="text-sm text-[color:var(--muted-foreground)]">None found.</span>
                  <% else %>
                    <%= for token_id <- @services.holdings.animata2 do %>
                      <a
                        href={opensea_item_url(:animata2, token_id)}
                        target="_blank"
                        rel="noreferrer"
                        class="rounded-full border border-[color:var(--border)] px-3 py-1.5 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        #{token_id}
                      </a>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
              <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <p class="text-sm text-[color:var(--muted-foreground)]">
                  Remaining Animata I redemptions:
                  <span class="text-[color:var(--foreground)]">
                    {redeem_supply_value(@services.redeem_supply.animata)}
                  </span>
                </p>
                <p class="text-sm text-[color:var(--muted-foreground)]">
                  Remaining Animata II redemptions:
                  <span class="text-[color:var(--foreground)]">
                    {redeem_supply_value(@services.redeem_supply.regent_animata_ii)}
                  </span>
                </p>
              </div>

              <%= if @services.redeem_supply_notice do %>
                <.inline_notice notice={@services.redeem_supply_notice} class="mt-4" />
              <% end %>
            </div>
          </div>
        </section>

        <section
          id="services-name-claim"
          phx-hook="DashboardNameClaim"
          data-dashboard-config={@claim_island_config}
          class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5"
        >
          <div class="space-y-3">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Name claim
            </p>
            <h3 class="font-display text-2xl text-[color:var(--foreground)]">
              Claim your Regent identity
            </h3>
            <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
              Choose a name, see whether it is open, and finish the wallet step when you are ready.
            </p>
          </div>

          <div class="mt-5 grid gap-4 sm:grid-cols-2">
            <.metric_tile
              label="Snapshot claims left"
              value={Integer.to_string(allowance_remaining(@services))}
              copy="Still open to this wallet"
            />
            <.metric_tile
              label="Snapshot total"
              value={Integer.to_string(snapshot_total(@services))}
              copy="Original wallet allocation"
            />
          </div>

          <%= if @services.allowance_notice do %>
            <.inline_notice notice={@services.allowance_notice} class="mt-4" />
          <% end %>
          <%= if @services.basenames_config_notice do %>
            <.inline_notice notice={@services.basenames_config_notice} class="mt-4" />
          <% end %>

          <div class="mt-5 space-y-5">
            <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                Recent names
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <%= if @services.recent_names == [] do %>
                  <span class="text-sm text-[color:var(--muted-foreground)]">
                    No names claimed yet.
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

            <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4">
              <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                My claimed names
              </p>

              <%= if @services.owned_names_notice do %>
                <.inline_notice notice={@services.owned_names_notice} class="mt-3" />
              <% end %>

              <div class="mt-3 grid gap-3 sm:grid-cols-2">
                <%= if @services.owned_names == [] do %>
                  <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                    Sign in and claim a name to see it here.
                  </div>
                <% else %>
                  <%= for name <- @services.owned_names do %>
                    <div class="rounded-2xl border border-[color:var(--border)] px-4 py-4">
                      <p class="font-display text-lg text-[color:var(--foreground)]">
                        {name.ens_fqdn || name.fqdn}
                      </p>
                      <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                        {if name.is_in_use, do: "Already tied to a company.", else: "Ready to use."}
                      </p>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <div class="grid gap-4 xl:grid-cols-2">
              <.form
                for={@phase1_form}
                id="phase1-claim-form"
                phx-change="change_phase1_label"
                class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4"
              >
                <div class="space-y-3">
                  <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Snapshot claim
                  </p>
                  <.input
                    id="phase1-name-input"
                    field={@phase1_form[:label]}
                    type="text"
                    placeholder="alice"
                    autocomplete="off"
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
                id="phase2-claim-form"
                phx-change="change_phase2_label"
                class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4"
              >
                <div class="space-y-3">
                  <p class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Public claim
                  </p>
                  <.input
                    id="phase2-name-input"
                    field={@phase2_form[:label]}
                    type="text"
                    placeholder="alice"
                    autocomplete="off"
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
            </div>

            <p data-dashboard-claim-notice class="hidden text-sm leading-6"></p>
          </div>
        </section>
      </div>
    </div>
    """
  end

  attr :formation, :map, default: nil
  attr :formation_token_cards, :map, default: %{}
  attr :notice, :map, default: nil
  attr :stage, :atom, required: true
  attr :selected_claimed_label, :string, default: nil
  attr :launching_slug, :string, default: nil
  attr :wallet_ready?, :boolean, required: true

  defp agent_formation_view(assigns) do
    ~H"""
    <div class="space-y-8">
      <%= if @notice do %>
        <.inline_notice notice={@notice} />
      <% end %>

      <%= if @formation do %>
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <.metric_tile
            label="Passes found"
            value={Integer.to_string(total_eligible_tokens(@formation))}
            copy="Across Collection I, Collection II, and Regents Club"
          />
          <.metric_tile
            label="Unused names"
            value={Integer.to_string(length(@formation.available_claims))}
            copy="Ready for a new company"
          />
          <.metric_tile
            label="Billing"
            value={billing_value(@formation.billing_account)}
            copy="Needed before launch"
          />
          <.metric_tile
            label="Companies"
            value={Integer.to_string(length(@formation.owned_companies))}
            copy="Already tied to this account"
          />
        </div>

        <%= if not @formation.authenticated or not @formation.eligible or @stage == :gate do %>
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Access
              </p>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Check wallet access
              </h3>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Start here by signing in and confirming that this wallet holds a pass from Collection I, Collection II, or Regents Club.
              </p>
            </div>

            <div class="mt-5 flex flex-wrap items-center justify-end gap-3">
              <a
                href="https://opensea.io/collection/regents-club"
                target="_blank"
                rel="noreferrer"
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Buy a pass
              </a>

              <button
                :if={@formation.authenticated and @formation.eligible}
                type="button"
                phx-click="continue_formation"
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
              >
                Continue
              </button>
            </div>
          </section>
        <% end %>

        <%= if @formation.authenticated and @formation.eligible and @stage == :setup do %>
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Setup
              </p>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Launch your company
              </h3>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                Finish the launch in this order: choose a claimed name, set up billing, then start the company.
              </p>
            </div>

            <%= if @formation.available_claims == [] do %>
              <.inline_notice
                notice={
                  %{
                    tone: :info,
                    message: "You need at least one unused name before you can continue."
                  }
                }
                class="mt-5"
              />
            <% else %>
              <.form
                for={to_form(%{"claimed_label" => @selected_claimed_label}, as: :formation_setup)}
                id="agent-formation-setup-form"
                phx-change="change_selected_claim"
                class="mt-5 space-y-5"
              >
                <label class="space-y-2">
                  <span class="text-xs uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                    Unused name
                  </span>
                  <.input
                    field={
                      to_form(%{"claimed_label" => @selected_claimed_label}, as: :formation_setup)[
                        :claimed_label
                      ]
                    }
                    type="select"
                    options={formation_claim_options(@formation.available_claims)}
                    class="w-full rounded-xl border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)]"
                  />
                </label>

                <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] p-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  <p>
                    Public site:
                    <span class="text-[color:var(--foreground)]">
                      {selected_hostname(@selected_claimed_label)}
                    </span>
                  </p>
                  <p class="mt-2">
                    Identity:
                    <span class="text-[color:var(--foreground)]">
                      {selected_identity(@formation.available_claims, @selected_claimed_label)}
                    </span>
                  </p>
                </div>

                <%= if @formation.billing_account.welcome_credit do %>
                  <div class="rounded-2xl border border-[color:color-mix(in_oklch,var(--positive)_45%,var(--border)_55%)] bg-[color:color-mix(in_oklch,var(--positive)_9%,transparent)] p-4">
                    <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                      Launch credit
                    </p>
                    <p class="mt-2 font-display text-xl text-[color:var(--foreground)]">
                      {format_usd_cents(@formation.billing_account.welcome_credit.amount_usd_cents)} added
                    </p>
                    <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      You received launch credit for sprite runtime. It expires on {format_credit_expiry(
                        @formation.billing_account.welcome_credit.expires_at
                      )}. Model usage is billed separately.
                    </p>
                  </div>
                <% end %>

                <%= if @formation.billing_account.connected do %>
                  <.inline_notice notice={
                    %{
                      tone: :success,
                      message: "Billing is ready. You can launch this company now."
                    }
                  } />
                  <div class="flex flex-wrap justify-end gap-3">
                    <button
                      type="button"
                      phx-click="start_company"
                      class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                    >
                      Launch this company
                    </button>
                  </div>
                <% else %>
                  <.inline_notice notice={
                    %{
                      tone: :info,
                      message: "Set up billing before you launch this company."
                    }
                  } />
                  <div class="flex flex-wrap justify-end gap-3">
                    <button
                      type="button"
                      phx-click="start_billing_setup"
                      class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                    >
                      Set up billing
                    </button>
                  </div>
                <% end %>
              </.form>
            <% end %>
          </section>
        <% end %>

        <%= if @launching_slug && launch_company(@formation, @launching_slug) do %>
          <.launch_progress
            company={launch_company(@formation, @launching_slug)}
            formation={launch_formation(@formation, @launching_slug)}
          />
        <% end %>

        <div class="space-y-6">
          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Claimed names
              </p>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Names tied to this wallet
              </h3>
            </div>

            <div class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              <%= if @formation.claimed_names == [] do %>
                <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                  No claimed names yet.
                </div>
              <% else %>
                <%= for claim <- @formation.claimed_names do %>
                  <div class="rounded-2xl border border-[color:var(--border)] px-4 py-4">
                    <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                      <p class="font-display break-all text-lg text-[color:var(--foreground)]">
                        {claim.ens_fqdn || "#{claim.label}.regent.eth"}
                      </p>
                      <a
                        :if={active_claim_company(@formation, claim)}
                        href={active_claim_company_url(@formation, claim)}
                        class="text-sm underline decoration-[color:var(--foreground)] underline-offset-4 text-[color:var(--foreground)] transition hover:text-[color:var(--muted-foreground)]"
                      >
                        Active
                      </a>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </section>

          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5">
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div class="space-y-3">
                <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                  Passes Owned
                </p>
                <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                  Regents Club
                </h3>
              </div>

              <a
                href="https://opensea.io/collection/regents-club"
                target="_blank"
                rel="noreferrer"
                class="inline-flex items-center gap-3 rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_88%,transparent)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] hover:-translate-y-0.5"
              >
                <.opensea_mark />
                <span>OpenSea</span>
              </a>
            </div>

            <div
              id="agent-formation-pass-gallery"
              phx-hook="FormationPassGallery"
              data-token-card-budget="10"
              data-token-card-chunk="2"
              class="mt-5 grid justify-items-center gap-x-5 gap-y-6 sm:grid-cols-2 xl:grid-cols-3"
            >
              <%= if @formation.collections.animata_pass == [] do %>
                <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)] sm:col-span-2 xl:col-span-3">
                  No Regents Club passes found for this wallet.
                </div>
              <% else %>
                <%= for token_id <- @formation.collections.animata_pass do %>
                  <a
                    href={opensea_item_url(:regents_club, token_id)}
                    target="_blank"
                    rel="noreferrer"
                    class="group inline-flex shrink-0 transition hover:-translate-y-1"
                    aria-label={"Open Regents Club ##{token_id} on OpenSea"}
                  >
                    <%= if entry = Map.get(@formation_token_cards, token_id) do %>
                      <div
                        data-token-card-root
                        data-token-card-entry={PlatformPhxWeb.TokenCardPayload.encode(entry)}
                        data-token-card-layout="embedded"
                        data-token-card-active="false"
                      >
                      </div>
                    <% else %>
                      <div class="flex min-h-[22rem] min-w-[15rem] items-center justify-center rounded-[1.2rem] border border-dashed border-[color:var(--border)] px-4 text-center text-xs uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                        Card unavailable
                      </div>
                    <% end %>
                  </a>
                <% end %>
              <% end %>
            </div>
          </section>
        </div>

        <div class="grid gap-6 xl:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
          <section
            id="agent-formation-history"
            phx-hook="FormationHistory"
            class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5"
          >
            <div class="flex items-center justify-between gap-3">
              <div class="space-y-2">
                <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                  Active formation
                </p>
                <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                  Launch progress
                </h3>
              </div>
              <button
                type="button"
                phx-click="refresh_formation"
                class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
              >
                Refresh
              </button>
            </div>

            <div class="mt-5 space-y-3">
              <%= if @formation.active_formations == [] do %>
                <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                  No launch is running right now.
                </div>
              <% else %>
                <%= for formation <- @formation.active_formations do %>
                  <div class="rounded-2xl border border-[color:var(--border)] px-4 py-4">
                    <div class="flex flex-wrap items-center justify-between gap-3">
                      <div>
                        <p class="font-display text-lg text-[color:var(--foreground)]">
                          {formation.claimed_label || formation.current_step}
                        </p>
                        <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                          Step: {formation.current_step}
                        </p>
                      </div>
                      <div class="flex flex-wrap items-center gap-2">
                        <span class={status_badge_class(formation.status)}>
                          {formation.status}
                        </span>
                        <button
                          type="button"
                          class="inline-flex items-center gap-2 rounded-full border border-[color:var(--border)] px-3 py-1.5 text-xs uppercase tracking-[0.14em] text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] hover:bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)]"
                          data-formation-toggle
                          data-target-id={formation_history_panel_id(formation)}
                          aria-expanded="false"
                          aria-controls={formation_history_panel_id(formation)}
                        >
                          <span>Expand</span>
                          <span aria-hidden="true">↓</span>
                        </button>
                      </div>
                    </div>

                    <%= if formation.last_error_message do %>
                      <p class="mt-3 text-sm text-[color:#a6574f]">
                        {formation.last_error_message}
                      </p>
                    <% end %>

                    <div
                      id={formation_history_panel_id(formation)}
                      class="pp-formation-history-drawer"
                      data-formation-history-panel
                      hidden
                    >
                      <div class="pp-formation-history-drawer-inner">
                        <div class="flex items-center justify-between gap-3">
                          <div>
                            <p class="text-[10px] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                              Past actions
                            </p>
                            <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                              Scroll through every launch step for this company.
                            </p>
                          </div>
                          <p
                            :if={formation.last_heartbeat_at}
                            class="text-[10px] uppercase tracking-[0.14em] text-[color:var(--muted-foreground)]"
                          >
                            Last update {formation_event_time(formation.last_heartbeat_at)}
                          </p>
                        </div>

                        <div class="pp-formation-history-scroll">
                          <%= if Map.get(formation, :events, []) == [] do %>
                            <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                              No actions recorded yet.
                            </div>
                          <% else %>
                            <%= for event <- Map.get(formation, :events, []) do %>
                              <article class="pp-formation-history-event">
                                <div class="flex items-start justify-between gap-3">
                                  <div class="space-y-1">
                                    <p class="font-display text-base text-[color:var(--foreground)]">
                                      {formation_step_title(event.step)}
                                    </p>
                                    <p
                                      :if={event.message}
                                      class="text-sm leading-6 text-[color:var(--muted-foreground)]"
                                    >
                                      {event.message}
                                    </p>
                                  </div>
                                  <span class={formation_event_status_class(event.status)}>
                                    {event.status}
                                  </span>
                                </div>
                                <p
                                  :if={formation_event_time(event.created_at)}
                                  class="mt-3 text-[10px] uppercase tracking-[0.14em] text-[color:var(--muted-foreground)]"
                                >
                                  {formation_event_time(event.created_at)}
                                </p>
                              </article>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </section>

          <section class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,var(--card)_5%)] p-5">
            <div class="space-y-2">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Live Regents
              </p>
              <h3 class="font-display text-2xl text-[color:var(--foreground)]">
                Active Agent Companies
              </h3>
            </div>

            <div class="mt-5 space-y-3">
              <%= if @formation.owned_companies == [] do %>
                <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
                  No companies created yet.
                </div>
              <% else %>
                <%= for company <- @formation.owned_companies do %>
                  <div class="rounded-2xl border border-[color:var(--border)] px-4 py-4">
                    <div class="flex flex-wrap items-center justify-between gap-3">
                      <div>
                        <p class="font-display text-lg text-[color:var(--foreground)]">
                          {company.name}
                        </p>
                        <p class="mt-1 text-sm text-[color:var(--muted-foreground)]">
                          {company.slug}.regents.sh
                        </p>
                      </div>
                      <span class={status_badge_class(company.runtime_status)}>
                        {company.runtime_status}
                      </span>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </section>
        </div>
      <% else %>
        <div class="rounded-2xl border border-dashed border-[color:var(--border)] px-4 py-5 text-sm text-[color:var(--muted-foreground)]">
          Agent Formation is unavailable right now.
        </div>
      <% end %>
    </div>
    """
  end

  attr :company, :map, required: true
  attr :formation, :map, default: nil

  defp launch_progress(assigns) do
    ~H"""
    <section
      id="agent-formation-launch-progress"
      phx-hook="LaunchProgress"
      class="overflow-hidden rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--brand-1)_28%,var(--border)_72%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-1)_10%,var(--card)_90%),color-mix(in_oklch,var(--background)_92%,var(--card)_8%))] px-5 py-5 shadow-[0_28px_90px_-56px_color-mix(in_oklch,var(--brand-1)_35%,transparent)] sm:px-6"
    >
      <div class="grid gap-5 lg:grid-cols-[minmax(0,1.25fr)_minmax(18rem,0.75fr)]">
        <div class="pp-launch-progress-copy space-y-4">
          <div class="space-y-3">
            <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
              Launching now
            </p>
            <h3 class="font-display text-[clamp(2rem,4vw,3rem)] leading-[0.92] text-[color:var(--foreground)]">
              We’re opening {@company.subdomain.hostname}
            </h3>
            <p class="max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
              Stay on this page for a moment. As soon as your company home is ready, we’ll send you there automatically.
            </p>
          </div>

          <div class="grid gap-3 sm:grid-cols-3">
            <div class="pp-launch-progress-card rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] px-4 py-4">
              <p class="text-[10px] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                Company name
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
              <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                1. Finish setup
              </p>
              <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                We finish the launch steps behind the scenes.
              </p>
            </div>

            <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
              <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                2. Open your company site
              </p>
              <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                Your public home goes live at {@company.subdomain.hostname}.
              </p>
            </div>

            <div class="pp-launch-progress-card rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card-elevated)] px-4 py-3">
              <p class="font-display text-[1rem] text-[color:var(--foreground)]">
                3. Land on your new home
              </p>
              <p class="mt-1 text-sm leading-6 text-[color:var(--muted-foreground)]">
                You’ll be sent there automatically as soon as it is ready.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :state, :map, required: true

  defp availability_state(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if @state.label_error do %>
        <p class="text-sm text-[color:#a6574f]">
          {@state.label_error}
        </p>
      <% end %>

      <%= if @state.valid? do %>
        <div class="flex flex-wrap gap-2 text-xs uppercase tracking-[0.16em]">
          <span class={availability_badge_class(@state)}>
            {availability_badge_label(@state)}
          </span>
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

  defp inline_notice(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border px-4 py-3 text-sm leading-6",
      notice_class(@notice.tone),
      @class
    ]}>
      {@notice.message}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :copy, :string, required: true

  defp metric_tile(assigns) do
    ~H"""
    <div class="rounded-2xl border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] p-4">
      <div class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
        {@label}
      </div>
      <div class="mt-3 font-display text-2xl text-[color:var(--foreground)]">
        {@value}
      </div>
      <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
        {@copy}
      </p>
    </div>
    """
  end

  defp load_page_payload(socket) do
    case socket.assigns.live_action do
      :agent_formation -> load_formation_payload(socket)
      _other -> load_services_payload(socket)
    end
  end

  defp load_services_payload(socket) do
    {:ok, services} = Dashboard.services_payload(socket.assigns.current_human)

    socket
    |> assign(:services, services)
    |> refresh_name_claim_states()
  end

  defp load_formation_payload(socket) do
    {:ok, result} = Dashboard.agent_formation_payload(socket.assigns.current_human)

    socket =
      socket
      |> assign(:formation_data, result.formation)
      |> assign(:formation_notice, result.notice)
      |> assign(:formation_token_cards, formation_token_cards(result.formation))
      |> sync_selected_claim()
      |> maybe_redirect_to_company_site()

    maybe_schedule_refresh(socket)
  end

  defp maybe_schedule_refresh(socket) do
    if connected?(socket) and
         (active_formation?(socket.assigns.formation_data) or awaiting_billing_ready?(socket)) do
      Process.send_after(self(), :refresh_formation_payload, @refresh_ms)
    end

    socket
  end

  defp maybe_redirect_to_company_site(%{assigns: %{launching_slug: nil}} = socket), do: socket

  defp maybe_redirect_to_company_site(socket) do
    company =
      socket.assigns.formation_data.owned_companies
      |> Enum.find(&(&1.slug == socket.assigns.launching_slug))

    if company_ready_for_redirect?(company) do
      redirect(socket, external: "https://#{company.subdomain.hostname}")
    else
      socket
    end
  end

  defp maybe_put_billing_return_flash(%{assigns: %{billing_return_state: nil}} = socket),
    do: socket

  defp maybe_put_billing_return_flash(socket) do
    case socket.assigns.billing_return_state do
      :success ->
        message =
          if socket.assigns.formation_data &&
               socket.assigns.formation_data.billing_account.connected do
            "Billing is ready. You can launch your company now."
          else
            "Finishing billing setup now. This page will update automatically."
          end

        put_flash(socket, :info, message)

      :cancel ->
        put_flash(socket, :error, "Billing setup was cancelled.")
    end
  end

  defp normalize_billing_return_state("success"), do: :success
  defp normalize_billing_return_state("cancel"), do: :cancel
  defp normalize_billing_return_state(_value), do: nil

  defp awaiting_billing_ready?(%{
         assigns: %{
           billing_return_state: :success,
           formation_data: %{billing_account: billing_account}
         }
       }) do
    billing_account.connected != true
  end

  defp awaiting_billing_ready?(_socket), do: false

  defp company_ready_for_redirect?(%{
         status: "published",
         subdomain: %{active: true, hostname: hostname}
       })
       when is_binary(hostname) and hostname != "" do
    true
  end

  defp company_ready_for_redirect?(_company), do: false

  defp sync_selected_claim(%{assigns: %{formation_data: nil}} = socket), do: socket

  defp sync_selected_claim(socket) do
    claims = socket.assigns.formation_data.available_claims
    requested = socket.assigns.requested_claimed_label
    current = socket.assigns.selected_claimed_label

    selected_claimed_label =
      cond do
        requested && Enum.any?(claims, &(&1.label == requested)) ->
          requested

        current && Enum.any?(claims, &(&1.label == current)) ->
          current

        true ->
          claims |> List.first() |> then(&if(&1, do: &1.label, else: nil))
      end

    assign(socket, :selected_claimed_label, selected_claimed_label)
  end

  defp refresh_name_claim_states(socket) do
    parent_name =
      socket.assigns.services.basenames_config &&
        socket.assigns.services.basenames_config.parent_name

    ens_parent_name =
      socket.assigns.services.basenames_config &&
        socket.assigns.services.basenames_config.ens_parent_name

    socket
    |> assign(
      :phase1_state,
      Dashboard.name_claim_state(socket.assigns.phase1_label, parent_name, ens_parent_name)
    )
    |> assign(
      :phase2_state,
      Dashboard.name_claim_state(socket.assigns.phase2_label, parent_name, ens_parent_name)
    )
    |> assign_forms()
  end

  defp assign_forms(socket) do
    socket
    |> assign(:phase1_form, to_form(%{"label" => socket.assigns.phase1_label}, as: :phase1_claim))
    |> assign(:phase2_form, to_form(%{"label" => socket.assigns.phase2_label}, as: :phase2_claim))
  end

  defp formation_path(socket, stage, launch_slug \\ nil) do
    params =
      case stage do
        :setup ->
          current = normalize_claimed_label(socket.assigns.selected_claimed_label)

          %{}
          |> Map.put("stage", "setup")
          |> maybe_put_claimed_label(current)
          |> maybe_put_launch_slug(launch_slug)

        _other ->
          %{}
      end

    ~p"/agent-formation?#{params}"
  end

  defp maybe_put_claimed_label(params, nil), do: params

  defp maybe_put_claimed_label(params, claimed_label),
    do: Map.put(params, "claimedLabel", claimed_label)

  defp maybe_put_launch_slug(params, nil), do: params
  defp maybe_put_launch_slug(params, launch_slug), do: Map.put(params, "launch", launch_slug)

  defp normalize_claimed_label(nil), do: nil

  defp normalize_claimed_label(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_claimed_label(_value), do: nil

  defp dashboard_page(:agent_formation) do
    %{
      page_title: "Agent Formation",
      active_nav: "agent-formation",
      console_id: "agent-formation-wallet-console",
      console_eyebrow: "Agent Formation",
      console_title: "Launch your company",
      console_copy:
        "Finish the launch in this order: choose a claimed name, set up billing, then start the company."
    }
  end

  defp dashboard_page(_view) do
    %{
      page_title: "Services",
      active_nav: "services",
      console_id: "services-wallet-console",
      console_eyebrow: "Services",
      console_title: "Prepare your account",
      console_copy:
        "Use this page to check wallet access, redeem passes, claim names, and get ready for company launch."
    }
  end

  defp opensea_item_url(:animata1, token_id) when is_integer(token_id) do
    "https://opensea.io/item/base/0x78402119ec6349a0d41f12b54938de7bf783c923/#{token_id}"
  end

  defp opensea_item_url(:animata2, token_id) when is_integer(token_id) do
    "https://opensea.io/item/base/0x903c4c1e8b8532fbd3575482d942d493eb9266e2/#{token_id}"
  end

  defp opensea_item_url(:regents_club, token_id) when is_integer(token_id) do
    "https://opensea.io/item/base/0x2208aadbdecd47d3b4430b5b75a175f6d885d487/#{token_id}"
  end

  defp claim_island_config do
    %{
      privyAppId: RuntimeConfig.privy_app_id(),
      privyClientId: RuntimeConfig.privy_client_id(),
      privySession: "/api/auth/privy/session",
      basenamesMint: "/api/basenames/mint",
      baseRpcUrl: RuntimeConfig.base_rpc_url()
    }
  end

  defp redeem_island_config do
    %{
      privyAppId: RuntimeConfig.privy_app_id(),
      privyClientId: RuntimeConfig.privy_client_id(),
      privySession: "/api/auth/privy/session",
      baseRpcUrl: RuntimeConfig.base_rpc_url(),
      redeemerAddress: RuntimeConfig.redeemer_address()
    }
  end

  defp wallet_ready? do
    RuntimeConfig.privy_app_id() not in [nil, ""] and
      RuntimeConfig.privy_client_id() not in [nil, ""]
  end

  defp empty_services do
    %{
      authenticated: false,
      wallet_address: nil,
      basenames_config: nil,
      basenames_config_notice: nil,
      allowance: nil,
      allowance_notice: nil,
      owned_names: [],
      owned_names_notice: nil,
      recent_names: [],
      recent_names_notice: nil,
      claimed_names: [],
      available_claims: [],
      holdings: %{animata1: [], animata2: [], animata_pass: []},
      holdings_notice: nil,
      redeem_supply: %{animata: nil, regent_animata_ii: nil},
      redeem_supply_notice: nil
    }
  end

  defp formation_token_cards(%{collections: %{animata_pass: token_ids}})
       when is_list(token_ids) do
    case TokenCardManifest.fetch_many(token_ids) do
      {:ok, entries} ->
        entries
        |> Enum.reject(fn {_token_id, entry} -> is_nil(entry) end)
        |> Map.new()

      {:error, _reason} ->
        %{}
    end
  end

  defp formation_token_cards(_formation), do: %{}

  defp can_free_claim?(services, state, wallet_ready?) do
    wallet_ready? and is_map(services.allowance) and
      services.allowance.free_mints_remaining > 0 and
      state.valid? and
      state.available? == true and not state.reserved?
  end

  defp can_paid_claim?(services, state, wallet_ready?) do
    wallet_ready? and is_map(services.basenames_config) and
      services.basenames_config.payment_recipient not in [nil, ""] and
      state.valid? and state.available? == true and not state.reserved?
  end

  defp allowance_remaining(%{allowance: %{free_mints_remaining: value}}), do: value
  defp allowance_remaining(_services), do: 0

  defp snapshot_total(%{allowance: %{snapshot_total: value}}), do: value
  defp snapshot_total(_services), do: 0

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

  defp availability_badge_class(%{reserved?: true}) do
    "rounded-full border border-[color:#a6574f] px-3 py-1 text-[color:#a6574f]"
  end

  defp availability_badge_class(%{available?: true}) do
    "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-[color:var(--foreground)]"
  end

  defp availability_badge_class(%{available?: false}) do
    "rounded-full border border-[color:#a6574f] px-3 py-1 text-[color:#a6574f]"
  end

  defp availability_badge_class(_state) do
    "rounded-full border border-[color:var(--border)] px-3 py-1 text-[color:var(--muted-foreground)]"
  end

  defp notice_class(:success) do
    "border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] bg-[color:color-mix(in_oklch,var(--positive)_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp notice_class(:error) do
    "border-[color:#a6574f] bg-[color:color-mix(in_oklch,#a6574f_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp notice_class(_tone) do
    "border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] text-[color:var(--foreground)]"
  end

  defp redeem_supply_value(nil), do: "--"
  defp redeem_supply_value(value), do: Integer.to_string(value)

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

  defp selected_hostname(nil), do: "--"
  defp selected_hostname(claimed_label), do: "#{claimed_label}.regents.sh"

  defp selected_identity(claims, claimed_label) do
    claims
    |> Enum.find(&(&1.label == claimed_label))
    |> then(fn
      nil -> "--"
      claim -> claim.ens_fqdn || "#{claim.label}.regent.eth"
    end)
  end

  defp active_formation?(nil), do: false

  defp active_formation?(formation) do
    Enum.any?(formation.active_formations, &(&1.status in ["queued", "running"]))
  end

  defp formation_history_panel_id(%{id: id}) when not is_nil(id), do: "formation-history-#{id}"
  defp formation_history_panel_id(_formation), do: "formation-history"

  defp formation_step_title("reserve_claim"), do: "Reserved the name"
  defp formation_step_title("create_sprite"), do: "Started the sprite"
  defp formation_step_title("bootstrap_sprite"), do: "Prepared the sprite"
  defp formation_step_title("bootstrap_paperclip"), do: "Connected Paperclip"
  defp formation_step_title("create_company"), do: "Built the company home"
  defp formation_step_title("create_hermes"), do: "Prepared Hermes"
  defp formation_step_title("create_checkpoint"), do: "Saved a checkpoint"
  defp formation_step_title("activate_subdomain"), do: "Turned on the public site"
  defp formation_step_title("finalize"), do: "Finished launch"

  defp formation_step_title(step) when is_binary(step) do
    step
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp formation_step_title(_step), do: "Launch step"

  defp formation_event_status_class("succeeded") do
    "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] px-3 py-1 text-[10px] uppercase tracking-[0.16em] text-[color:var(--foreground)]"
  end

  defp formation_event_status_class("failed") do
    "rounded-full border border-[color:#a6574f] px-3 py-1 text-[10px] uppercase tracking-[0.16em] text-[color:#a6574f]"
  end

  defp formation_event_status_class(_status) do
    "rounded-full border border-[color:var(--border)] px-3 py-1 text-[10px] uppercase tracking-[0.16em] text-[color:var(--muted-foreground)]"
  end

  defp formation_event_time(nil), do: nil

  defp formation_event_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%b %-d, %H:%M UTC")
      _other -> nil
    end
  end

  defp formation_event_time(_value), do: nil

  defp active_claim_company(%{owned_companies: companies}, claim) when is_list(companies) do
    Enum.find(companies, fn company ->
      company.slug == claim.label and company.status == "published" and
        get_in(company, [:subdomain, :active]) == true and
        is_binary(get_in(company, [:subdomain, :hostname]))
    end)
  end

  defp active_claim_company(_formation, _claim), do: nil

  defp active_claim_company_url(formation, claim) do
    case active_claim_company(formation, claim) do
      %{subdomain: %{hostname: hostname}} when is_binary(hostname) and hostname != "" ->
        "https://#{hostname}"

      _company ->
        "#"
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

  defp launch_company(nil, _slug), do: nil

  defp launch_company(formation, slug) do
    Enum.find(formation.owned_companies, &(&1.slug == slug))
  end

  defp launch_formation(nil, _slug), do: nil

  defp launch_formation(formation, slug) do
    Enum.find(formation.active_formations, &(&1.claimed_label == slug))
  end

  defp launch_step_label(nil), do: "Starting your company"

  defp launch_step_label(formation) do
    case formation.current_step do
      "reserve_claim" -> "Saving your company name"
      "create_sprite" -> "Starting your company"
      "bootstrap_sprite" -> "Preparing your company"
      "bootstrap_paperclip" -> "Connecting your company tools"
      "create_company" -> "Building your company home"
      "create_hermes" -> "Getting your assistant ready"
      "create_checkpoint" -> "Saving your first restore point"
      "activate_subdomain" -> "Opening your public site"
      "finalize" -> "Sending you to your company home"
      _other -> "Preparing your company"
    end
  end

  defp launch_step_copy(nil), do: "We’re preparing your company home."

  defp launch_step_copy(formation) do
    case formation.current_step do
      "activate_subdomain" ->
        "Your public site is being opened right now."

      "finalize" ->
        "Everything is almost ready. Your redirect comes next."

      _other ->
        "We’re working through the setup steps now."
    end
  end

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
end
