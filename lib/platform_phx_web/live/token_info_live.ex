defmodule PlatformPhxWeb.TokenInfoLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.RegentStaking
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhx.TokenInfoContent
  alias PlatformPhx.TokenMarketData

  @economics_sources [
    %{
      title: "Autolaunch",
      short: "Hook + auction fees",
      body_lines: [
        [
          %{type: :highlight, text: "1%"},
          %{
            type: :text,
            text: " of every agent token's trading fees from the Uniswap v4 fee hook"
          }
        ],
        [
          %{type: :highlight, text: "2%"},
          %{type: :text, text: " of raised USDC in CCA auctions."}
        ]
      ]
    },
    %{
      title: "Techtree",
      short: "Agent token earnings",
      body_lines: [
        [
          %{type: :highlight, text: "1%"},
          %{type: :text, text: " of agent token earnings."}
        ]
      ]
    },
    %{
      title: "Stablecoin Revenues",
      short: "Revsplit-tracked gross revenue",
      body_lines: [
        [
          %{type: :highlight, text: "1%"},
          %{
            type: :text,
            text:
              " of gross revenue for all agents, from x402, MPP, and other sources. Tracked onchain through the revsplit contract."
          }
        ]
      ]
    },
    %{
      title: "Regents Platform",
      short: "Hosted agent margin fees",
      body:
        "Openclaw and Hermes agent hosting, with Stripe LLM billing for margin fees on hosted Regents."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    token_market_summary =
      case TokenMarketData.fetch_summary() do
        {:ok, summary} -> summary
        {:error, _reason} -> %{market_cap_display: "--", fdv_display: "--"}
      end

    {staking, staking_notice} = load_staking(socket.assigns.current_human)

    {:ok,
     socket
     |> assign(:page_title, "Platform Token")
     |> assign(:economics_sources, @economics_sources)
     |> assign(:holders, TokenInfoContent.holders())
     |> assign(:allocations, TokenInfoContent.allocations())
     |> assign(:token_market_summary, token_market_summary)
     |> assign(:open_holder, nil)
     |> assign(:staking, staking)
     |> assign(:staking_notice, staking_notice)
     |> assign(:staking_form, to_form(%{"amount" => ""}, as: :staking))
     |> assign(:staking_amount, "")
     |> assign(:base_rpc_url, RuntimeConfig.base_rpc_url())
     |> assign(:base_sepolia_rpc_url, RuntimeConfig.regent_staking_rpc_url())}
  end

  @impl true
  def handle_event("toggle_holder", %{"rank" => rank}, socket) when is_binary(rank) do
    case Integer.parse(rank) do
      {parsed_rank, ""} ->
        next =
          if socket.assigns.open_holder == parsed_rank do
            nil
          else
            parsed_rank
          end

        {:noreply, assign(socket, :open_holder, next)}

      _other ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_holder", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("change_staking_amount", %{"staking" => %{"amount" => amount}}, socket) do
    {:noreply,
     socket
     |> assign(:staking_amount, amount)
     |> assign(:staking_form, to_form(%{"amount" => amount}, as: :staking))}
  end

  @impl true
  def handle_event("submit_staking", %{"action" => action}, socket) do
    params = %{"amount" => socket.assigns.staking_amount}

    case staking_action(action, params, socket.assigns.current_human) do
      {:ok, %{tx_request: tx_request}} ->
        {:noreply,
         socket
         |> assign(:staking_notice, %{tone: :info, message: staking_pending_copy(action)})
         |> push_event("regent-staking:tx-request", %{action: action, tx_request: tx_request})}

      {:error, {:unauthorized, _message}} ->
        {:noreply,
         assign(socket, :staking_notice, %{
           tone: :error,
           message: "Sign in with the wallet that holds your $REGENT first."
         })}

      {:error, {:bad_request, message}} ->
        {:noreply, assign(socket, :staking_notice, %{tone: :error, message: message})}

      {:error, :amount_required} ->
        {:noreply,
         assign(socket, :staking_notice, %{
           tone: :error,
           message: "Enter an amount before continuing."
         })}

      {:error, :invalid_amount_precision} ->
        {:noreply,
         assign(socket, :staking_notice, %{
           tone: :error,
           message: "That amount uses too many decimals."
         })}

      {:error, :unconfigured} ->
        {:noreply,
         assign(socket, :staking_notice, %{
           tone: :error,
           message: "Staking is unavailable right now."
         })}

      {:error, _reason} ->
        {:noreply,
         assign(socket, :staking_notice, %{
           tone: :error,
           message: "Could not prepare that staking action."
         })}
    end
  end

  @impl true
  def handle_event("staking_tx_complete", %{"action" => action}, socket) do
    {staking, _previous_notice} = load_staking(socket.assigns.current_human)

    {:noreply,
     socket
     |> assign(:staking, staking)
     |> assign(:staking_notice, %{tone: :success, message: staking_success_copy(action)})}
  end

  @impl true
  def handle_event("staking_tx_failed", %{"message" => message}, socket) do
    {:noreply, assign(socket, :staking_notice, %{tone: :error, message: message})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="token-info"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-token-info-shell"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="BridgeReveal"
      >
        <div class="pp-route-stage space-y-6">
          <section class="pp-route-panel pp-token-panel relative overflow-hidden" data-bridge-block>
            <div
              aria-hidden="true"
              class="pointer-events-none absolute inset-x-0 top-0 h-48 opacity-90"
              style="background:
                radial-gradient(circle at top left, color-mix(in oklch, var(--ring) 24%, transparent) 0, transparent 55%),
                linear-gradient(135deg, color-mix(in oklch, var(--background) 78%, var(--ring) 22%) 0%, transparent 58%);"
            >
            </div>

            <div class="relative grid gap-8 xl:grid-cols-[minmax(0,1.18fr)_minmax(21rem,0.82fr)]">
              <div class="space-y-6">
                <div class="space-y-4">
                  <p class="pp-home-kicker">Regent Token</p>
                  <h1 class="font-display text-[clamp(2.8rem,6vw,5.6rem)] leading-[0.86] tracking-[-0.05em] text-[color:var(--foreground)]">
                    Revenue that stays legible from source to stake.
                  </h1>
                  <p class="max-w-3xl text-[1rem] leading-7 text-[color:var(--muted-foreground)] sm:text-[1.05rem]">
                    $REGENT is the platform revsplit token. Stakers receive their share of
                    protocol revenue, and the remaining balance is used to buy back $REGENT.
                  </p>
                  <p class="max-w-3xl text-sm leading-6 text-[color:var(--muted-foreground)] sm:text-[0.95rem]">
                    This page is for holders, operators, and technical evaluators who need a clear
                    view of where revenue comes from, how staking pays, and what the major token
                    balances represent.
                  </p>
                </div>

                <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <.hero_metric
                    label="Market cap"
                    value={@token_market_summary.market_cap_display}
                    detail="Live market read"
                  />
                  <.hero_metric
                    label="Fully diluted"
                    value={@token_market_summary.fdv_display}
                    detail="Current supply view"
                  />
                  <.hero_metric
                    label="Revenue sources"
                    value="4"
                    detail="Product and protocol rails"
                  />
                  <.hero_metric
                    label="Stake rail"
                    value="Shared"
                    detail="Platform and Autolaunch"
                  />
                </div>

                <div class="grid gap-4 lg:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
                  <article class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_76%,var(--ring)_24%)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5 shadow-[0_20px_60px_-40px_color-mix(in_oklch,var(--foreground)_30%,transparent)]">
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                          Live markets
                        </p>
                        <h2 class="mt-3 font-display text-[1.5rem] leading-none text-[color:var(--foreground)]">
                          $REGENT on Base
                        </h2>
                      </div>
                      <div class="rounded-full border border-[color:var(--border)] px-3 py-1 text-[0.7rem] uppercase tracking-[0.2em] text-[color:var(--muted-foreground)]">
                        Base mainnet
                      </div>
                    </div>

                    <div class="mt-6 flex flex-wrap gap-3">
                      <.market_link
                        href="https://app.uniswap.org/explore/tokens/base/0x6f89bca4ea5931edfcb09786267b251dee752b07?inputCurrency=NATIVE"
                        label="View on Uniswap"
                        image_path={~p"/images/uniswaplogo.png"}
                        image_alt="Uniswap"
                      />
                      <.market_link
                        href="https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"
                        label="View on GeckoTerminal"
                        image_path={~p"/images/geckoterminallogo.png"}
                        image_alt="GeckoTerminal"
                      />
                      <.market_link
                        href="https://dexscreener.com/base/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"
                        label="View on Dexscreener"
                        image_path={~p"/images/dexscreenerlogo.png"}
                        image_alt="Dexscreener"
                      />
                    </div>
                  </article>

                  <article class="rounded-[2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,transparent)] p-5">
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                          Value path
                        </p>
                        <h2 class="mt-3 font-display text-[1.5rem] leading-none text-[color:var(--foreground)]">
                          Source, split, buyback
                        </h2>
                      </div>
                      <div class="rounded-full bg-[color:color-mix(in_oklch,var(--ring)_14%,transparent)] px-3 py-1 text-[0.7rem] uppercase tracking-[0.18em] text-[color:var(--foreground)]">
                        Always onchain
                      </div>
                    </div>

                    <div class="mt-6 space-y-4">
                      <.flow_row
                        title="1. Revenue enters"
                        body="Autolaunch, Techtree, stablecoin revenue, and Regents Platform feed the token economy."
                      />
                      <.flow_row
                        title="2. Stakers earn"
                        body="Stake $REGENT in the revsplit contract to receive your share and claim it when you want."
                      />
                      <.flow_row
                        title="3. Buybacks follow"
                        body="After the staker share is accounted for, the remaining balance is used to buy back $REGENT."
                      />
                    </div>
                  </article>
                </div>
              </div>

              <aside class="space-y-4">
                <article class="rounded-[2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,transparent)] p-5">
                  <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                    Why the token exists
                  </p>
                  <div class="mt-5 space-y-4">
                    <div class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                      <p class="font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                        Share revenue
                      </p>
                      <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Staking turns token ownership into a live claim on protocol revenue.
                      </p>
                    </div>
                    <div class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                      <p class="font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                        Support buybacks
                      </p>
                      <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        The balance left after the staker share is reserved for buying back
                        $REGENT.
                      </p>
                    </div>
                    <div class="rounded-[1.5rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                      <p class="font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                        Reward early staking
                      </p>
                      <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        During the first year, stakers also receive a 20% emissions stream.
                      </p>
                    </div>
                  </div>
                </article>

                <article class="rounded-[2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
                  <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                    Reading guide
                  </p>
                  <ul class="mt-5 space-y-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                    <li class="rounded-[1.2rem] border border-[color:var(--border)] px-4 py-3">
                      Use the revenue section to see where money enters the system.
                    </li>
                    <li class="rounded-[1.2rem] border border-[color:var(--border)] px-4 py-3">
                      Use the staking section to check balances, claimable amounts, and wallet
                      actions.
                    </li>
                    <li class="rounded-[1.2rem] border border-[color:var(--border)] px-4 py-3">
                      Use the holder and allocation sections to understand supply concentration and
                      lockups.
                    </li>
                  </ul>
                </article>
              </aside>
            </div>
          </section>

          <section
            id="platform-token-economics"
            class="pp-route-panel pp-token-panel"
            data-bridge-block
          >
            <div class="grid gap-6 xl:grid-cols-[minmax(0,1.04fr)_minmax(0,0.96fr)]">
              <div class="space-y-6">
                <div class="space-y-3">
                  <p class="pp-home-kicker">Revenue Sources</p>
                  <h2 class="pp-route-panel-title">Where money enters the Regent system</h2>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    These are the four current revenue rails feeding staking and buybacks.
                  </p>
                </div>

                <div class="grid gap-4">
                  <.source_card :for={source <- @economics_sources} source={source} />
                </div>
              </div>

              <div class="space-y-4">
                <div class="space-y-3">
                  <p class="pp-home-kicker">Staking Model</p>
                  <h2 class="pp-route-panel-title">How a dollar moves after it arrives</h2>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    The value path is simple on purpose so holders can evaluate it with confidence.
                  </p>
                </div>

                <div class="grid gap-4">
                  <article class="rounded-[2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-5">
                    <div class="flex items-start justify-between gap-4">
                      <div>
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                          Step 1
                        </p>
                        <h3 class="mt-3 font-display text-[1.35rem] leading-none text-[color:var(--foreground)]">
                          Stake into the revsplit contract
                        </h3>
                      </div>
                      <div class="rounded-full border border-[color:var(--border)] px-3 py-1 text-[0.7rem] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                        Claim anytime
                      </div>
                    </div>
                    <p class="mt-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      Stake $REGENT in the protocol revsplit contract to earn your share of stablecoin revenue.
                    </p>
                  </article>

                  <article class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_70%,var(--ring)_30%)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--ring)_10%)] p-5">
                    <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                      Step 2
                    </p>
                    <h3 class="mt-3 font-display text-[1.35rem] leading-none text-[color:var(--foreground)]">
                      Buybacks happen after the staker share
                    </h3>
                    <p class="mt-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      After the amount owed to stakers is accounted for, the remaining balance is
                      used to buy back $REGENT. At launch only about 20% of tokens are circulating,
                      so 80% or more of protocol skim can go to buybacks.
                    </p>
                  </article>

                  <article class="rounded-[2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-5">
                    <div class="flex items-start justify-between gap-4">
                      <div>
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                          Step 3
                        </p>
                        <h3 class="mt-3 font-display text-[1.35rem] leading-none text-[color:var(--foreground)]">
                          Early staking also earns emissions
                        </h3>
                      </div>
                      <div class="rounded-full bg-[color:color-mix(in_oklch,var(--ring)_14%,transparent)] px-3 py-1 text-[0.7rem] uppercase tracking-[0.18em] text-[color:var(--foreground)]">
                        20% first-year stream
                      </div>
                    </div>
                    <p class="mt-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      As the protocol builds during the first year, a 20% staking emissions reward
                      is streamed to stakers. Platform and Autolaunch open the same staking rail and
                      the same reward claims.
                    </p>
                  </article>
                </div>
              </div>
            </div>
          </section>

          <section
            id="platform-token-staking"
            class="pp-route-panel pp-token-panel"
            data-bridge-block
            phx-hook="TokenStaking"
            data-base-rpc-url={@base_rpc_url}
            data-base-sepolia-rpc-url={@base_sepolia_rpc_url}
          >
            <div class="grid gap-6 xl:grid-cols-[minmax(0,1.06fr)_minmax(0,0.94fr)]">
              <div class="space-y-5">
                <div class="space-y-3">
                  <p class="pp-home-kicker">Staking Console</p>
                  <h2 class="pp-route-panel-title">
                    Stake from Platform or Autolaunch. The underlying action is the same.
                  </h2>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    Platform and Autolaunch open the same staking contract, the same reward claims,
                    and the same wallet actions. Use either one.
                  </p>
                </div>

                <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  <.staking_metric
                    label="Network"
                    value={if(@staking, do: @staking.chain_label, else: "--")}
                  />
                  <.staking_metric
                    label="Total staked"
                    value={if(@staking, do: staking_value(@staking.total_staked), else: "--")}
                  />
                  <.staking_metric
                    label="Your staked balance"
                    value={if(@staking, do: staking_value(@staking.wallet_stake_balance), else: "--")}
                  />
                  <.staking_metric
                    label="Wallet balance"
                    value={if(@staking, do: staking_value(@staking.wallet_token_balance), else: "--")}
                  />
                  <.staking_metric
                    label="Claimable USDC"
                    value={
                      if(@staking, do: staking_value(@staking.wallet_claimable_usdc), else: "--")
                    }
                  />
                  <.staking_metric
                    label="Claimable REGENT"
                    value={
                      if(@staking, do: staking_value(@staking.wallet_claimable_regent), else: "--")
                    }
                  />
                </div>

                <div class="grid gap-4 lg:grid-cols-2">
                  <article class="rounded-[1.8rem] border border-[color:var(--border)] bg-[color:var(--background)] p-5">
                    <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                      What to expect
                    </p>
                    <ul class="mt-4 space-y-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      <li class="rounded-[1rem] border border-[color:var(--border)] px-4 py-3">
                        Stake and unstake use the amount you enter.
                      </li>
                      <li class="rounded-[1rem] border border-[color:var(--border)] px-4 py-3">
                        Claim actions use your live staking balances automatically.
                      </li>
                      <li class="rounded-[1rem] border border-[color:var(--border)] px-4 py-3">
                        After a successful wallet action, this page refreshes your staking snapshot.
                      </li>
                    </ul>
                  </article>

                  <article class="rounded-[1.8rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
                    <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                      Confidence check
                    </p>
                    <div class="mt-4 space-y-4">
                      <div class="rounded-[1rem] border border-[color:var(--border)] px-4 py-3">
                        <p class="font-display text-[1rem] leading-none text-[color:var(--foreground)]">
                          Shared rail
                        </p>
                        <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                          Platform and Autolaunch point to the same staking contract and claims.
                        </p>
                      </div>
                      <div class="rounded-[1rem] border border-[color:var(--border)] px-4 py-3">
                        <p class="font-display text-[1rem] leading-none text-[color:var(--foreground)]">
                          Wallet-first confirmation
                        </p>
                        <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                          Nothing happens until you confirm the action in your wallet.
                        </p>
                      </div>
                    </div>
                  </article>
                </div>
              </div>

              <div class="space-y-4">
                <section class="rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_72%,var(--ring)_28%)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--ring)_8%)] p-5">
                  <div class="flex items-center justify-between gap-4">
                    <div>
                      <p class="text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                        Wallet actions
                      </p>
                      <h3 class="mt-3 font-display text-[1.5rem] leading-none text-[color:var(--foreground)]">
                        Stake, unstake, and claim
                      </h3>
                    </div>
                    <div class="rounded-full border border-[color:var(--border)] px-3 py-1 text-[0.7rem] uppercase tracking-[0.18em] text-[color:var(--muted-foreground)]">
                      Live balances
                    </div>
                  </div>

                  <%= if @staking_notice do %>
                    <.staking_notice notice={@staking_notice} />
                  <% end %>

                  <%= if @staking do %>
                    <.form
                      for={@staking_form}
                      id="platform-token-staking-form"
                      phx-change="change_staking_amount"
                      class="mt-6 space-y-5"
                    >
                      <div class="space-y-2">
                        <label
                          for="platform-token-staking-amount"
                          class="text-[0.72rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]"
                        >
                          Amount
                        </label>
                        <.input
                          id="platform-token-staking-amount"
                          field={@staking_form[:amount]}
                          type="text"
                          placeholder="Amount of REGENT"
                          autocomplete="off"
                          class="w-full rounded-[1.25rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-4 text-base text-[color:var(--foreground)] shadow-none"
                        />
                      </div>

                      <div class="grid gap-3 sm:grid-cols-2">
                        <.staking_action_button
                          id="platform-token-stake-button"
                          action="stake"
                          label="Stake on Platform"
                          tone={:primary}
                        />
                        <.staking_action_button
                          id="platform-token-unstake-button"
                          action="unstake"
                          label="Unstake"
                        />
                        <.staking_action_button
                          id="platform-token-claim-usdc-button"
                          action="claim_usdc"
                          label="Claim USDC"
                        />
                        <.staking_action_button
                          id="platform-token-claim-regent-button"
                          action="claim_regent"
                          label="Claim REGENT"
                        />
                      </div>

                      <.staking_action_button
                        id="platform-token-restake-button"
                        action="claim_and_restake_regent"
                        label="Claim and restake REGENT"
                        wide={true}
                      />
                    </.form>

                    <p class="mt-5 text-sm leading-6 text-[color:var(--muted-foreground)]">
                      Prefer the launch surface? Autolaunch opens the same staking rail and the same
                      wallet calls.
                    </p>
                  <% else %>
                    <div class="mt-6 rounded-[1.4rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4">
                      <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Staking details are unavailable right now.
                      </p>
                    </div>
                  <% end %>
                </section>
              </div>
            </div>
          </section>

          <section class="pp-route-panel pp-token-panel" data-bridge-block>
            <div class="space-y-3">
              <p class="pp-home-kicker">Token Holders</p>
              <h2 class="pp-route-panel-title">Largest token balances and lockups</h2>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                As of April 1, 2026, most tokens are locked or held by the six addresses below.
                Open any row to see what that wallet or contract is doing.
              </p>
            </div>

            <div class="mt-6 space-y-3">
              <%= for holder <- @holders do %>
                <article class="overflow-hidden rounded-[1.8rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,transparent)]">
                  <div class="grid gap-4 px-5 py-5 lg:grid-cols-[4.5rem_minmax(0,1.15fr)_minmax(8rem,0.45fr)_minmax(11rem,0.62fr)_auto] lg:items-center">
                    <div class="flex h-12 w-12 items-center justify-center rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--background)] font-display text-[1.05rem] text-[color:var(--foreground)]">
                      {holder.rank}
                    </div>

                    <div class="min-w-0">
                      <p class="font-display text-[1.1rem] leading-none text-[color:var(--foreground)]">
                        {holder.label}
                      </p>
                      <a
                        href={"https://basescan.org/address/#{holder.address}"}
                        target="_blank"
                        rel="noreferrer"
                        class="mt-3 inline-flex max-w-full items-center gap-2 truncate text-sm text-[color:var(--muted-foreground)] transition hover:text-[color:var(--foreground)]"
                      >
                        <span class="truncate">{holder.short}</span>
                        <span aria-hidden="true">↗</span>
                      </a>
                    </div>

                    <div>
                      <p class="text-[0.7rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                        Share
                      </p>
                      <p class="mt-2 font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                        {holder.percent}
                      </p>
                    </div>

                    <div>
                      <div class="flex items-center justify-between gap-3">
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                          Amount
                        </p>
                        <p class="font-display text-[1rem] leading-none text-[color:var(--foreground)]">
                          {holder.amount}
                        </p>
                      </div>
                      <div class="mt-3 h-2 rounded-full bg-[color:color-mix(in_oklch,var(--foreground)_7%,transparent)]">
                        <div
                          class="h-full rounded-full bg-[color:var(--foreground)] transition-all duration-500"
                          style={"width: #{holder_percent_width(holder.percent)}"}
                        >
                        </div>
                      </div>
                    </div>

                    <div class="lg:justify-self-end">
                      <button
                        type="button"
                        class="inline-flex min-w-[8.5rem] items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] hover:bg-[color:color-mix(in_oklch,var(--ring)_10%,transparent)]"
                        phx-click="toggle_holder"
                        phx-value-rank={holder.rank}
                      >
                        {if @open_holder == holder.rank, do: "Hide details", else: "View details"}
                      </button>
                    </div>
                  </div>

                  <div
                    :if={@open_holder == holder.rank}
                    class="border-t border-[color:var(--border)] px-5 py-5"
                  >
                    <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-end">
                      <div>
                        <p class="text-[0.7rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                          What this balance represents
                        </p>
                        <p class="mt-3 max-w-3xl text-sm leading-6 text-[color:var(--muted-foreground)]">
                          {holder.description}
                        </p>
                      </div>
                      <a
                        :if={Map.has_key?(holder, :link_url)}
                        href={holder.link_url}
                        target="_blank"
                        rel="noreferrer"
                        class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                      >
                        {holder.link_label} <span aria-hidden="true" class="ml-2">↗</span>
                      </a>
                    </div>
                  </div>
                </article>
              <% end %>
            </div>

            <p class="mt-5 text-sm leading-6 text-[color:var(--muted-foreground)]">
              7th through 2,208th: Regent community members.
            </p>
          </section>

          <section class="pp-route-panel pp-token-panel" data-bridge-block>
            <div class="space-y-3">
              <p class="pp-home-kicker">Token Allocations</p>
              <h2 class="pp-route-panel-title">How the full token supply is assigned</h2>
              <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                At Clanker token deployment, the following extensions were configured: 20% Clanker
                public, 40% growth emissions, and 40% long-term incentives.
              </p>
            </div>

            <div class="mt-6 grid gap-4 xl:grid-cols-3">
              <%= for block <- @allocations do %>
                <section class="rounded-[2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,transparent)] p-5">
                  <div class="space-y-4">
                    <div class="space-y-3">
                      <p class="text-[0.7rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                        Allocation block
                      </p>
                      <h3 class="font-display text-[1.35rem] leading-[0.94] text-[color:var(--foreground)]">
                        {block.title}
                      </h3>
                    </div>

                    <div
                      :if={Map.has_key?(block, :body)}
                      class="space-y-3 text-sm leading-6 text-[color:var(--muted-foreground)]"
                    >
                      <p :for={paragraph <- block.body}>{paragraph}</p>
                    </div>

                    <div :if={Map.has_key?(block, :bullets)} class="space-y-3">
                      <article
                        :for={entry <- block.bullets}
                        class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4"
                      >
                        <p class="font-display text-[1rem] leading-none text-[color:var(--foreground)]">
                          {entry.label}
                        </p>
                        <ul
                          :if={entry.details != []}
                          class="mt-3 space-y-2 text-sm leading-6 text-[color:var(--muted-foreground)]"
                        >
                          <li :for={detail <- entry.details}>{detail}</li>
                        </ul>
                      </article>
                    </div>

                    <a
                      :if={Map.has_key?(block, :link_url)}
                      href={block.link_url}
                      target="_blank"
                      rel="noreferrer"
                      class="inline-flex items-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                    >
                      {block.link_label} <span aria-hidden="true" class="ml-2">↗</span>
                    </a>
                  </div>
                </section>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true

  defp hero_metric(assigns) do
    ~H"""
    <article class="rounded-[1.45rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_95%,transparent)] px-4 py-4">
      <p class="text-[0.68rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
        {@label}
      </p>
      <p class="mt-3 font-display text-[1.45rem] leading-none text-[color:var(--foreground)]">
        {@value}
      </p>
      <p class="mt-2 text-xs leading-5 text-[color:var(--muted-foreground)]">
        {@detail}
      </p>
    </article>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :image_path, :string, required: true
  attr :image_alt, :string, required: true

  defp market_link(assigns) do
    ~H"""
    <a
      href={@href}
      target="_blank"
      rel="noreferrer"
      class="inline-flex items-center gap-3 rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)] hover:bg-[color:color-mix(in_oklch,var(--ring)_8%,transparent)]"
      aria-label={@label}
      title={@label}
    >
      <img src={@image_path} alt={@image_alt} class="h-5 w-5 object-contain" />
      <span>{@image_alt}</span>
    </a>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true

  defp flow_row(assigns) do
    ~H"""
    <div class="grid gap-3 rounded-[1.35rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-4 sm:grid-cols-[9rem_minmax(0,1fr)] sm:items-start">
      <p class="text-[0.72rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
        {@title}
      </p>
      <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
        {@body}
      </p>
    </div>
    """
  end

  attr :source, :map, required: true

  defp source_card(assigns) do
    ~H"""
    <article class="rounded-[1.8rem] border border-[color:var(--border)] bg-[color:var(--background)] p-5">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="font-display text-[1.2rem] leading-none text-[color:var(--foreground)]">
            {@source.title}
          </p>
          <p class="mt-3 text-[0.72rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
            {@source.short}
          </p>
        </div>
      </div>
      <div class="mt-4 text-sm leading-6 text-[color:var(--muted-foreground)]">
        <%= if Map.has_key?(@source, :body_lines) do %>
          <%= for {line, index} <- Enum.with_index(@source.body_lines) do %>
            <.rich_fragments fragments={line} />
            <br :if={index < length(@source.body_lines) - 1} />
          <% end %>
        <% else %>
          {@source.body}
        <% end %>
      </div>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp staking_metric(assigns) do
    ~H"""
    <div class="rounded-[1.35rem] border border-[color:var(--border)] bg-[color:var(--background)] px-4 py-4">
      <p class="text-[0.68rem] font-semibold uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
        {@label}
      </p>
      <p class="mt-3 font-display text-[1.28rem] leading-none text-[color:var(--foreground)]">
        {@value}
      </p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :action, :string, required: true
  attr :label, :string, required: true
  attr :tone, :atom, default: :secondary
  attr :wide, :boolean, default: false

  defp staking_action_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-click="submit_staking"
      phx-value-action={@action}
      class={[
        "inline-flex items-center justify-center rounded-full border px-4 py-3 text-sm transition",
        @wide && "w-full",
        if(@tone == :primary,
          do:
            "border-[color:var(--foreground)] bg-[color:var(--foreground)] text-[color:var(--background)] hover:opacity-90",
          else:
            "border-[color:var(--border)] bg-[color:var(--background)] text-[color:var(--foreground)] hover:border-[color:var(--ring)] hover:bg-[color:color-mix(in_oklch,var(--ring)_8%,transparent)]"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :notice, :map, required: true

  defp staking_notice(assigns) do
    ~H"""
    <div class={[
      "mt-6 rounded-[1.2rem] border px-4 py-3 text-sm leading-6",
      staking_notice_class(@notice.tone)
    ]}>
      {@notice.message}
    </div>
    """
  end

  defp load_staking(current_human) do
    case RegentStaking.overview(current_human) do
      {:ok, staking} ->
        {staking, nil}

      {:error, :unconfigured} ->
        {nil, %{tone: :error, message: "Staking is unavailable right now."}}

      {:error, _reason} ->
        {nil, %{tone: :error, message: "Could not load staking details right now."}}
    end
  end

  defp staking_action("stake", params, current_human),
    do: RegentStaking.stake(params, current_human)

  defp staking_action("unstake", params, current_human),
    do: RegentStaking.unstake(params, current_human)

  defp staking_action("claim_usdc", params, current_human),
    do: RegentStaking.claim_usdc(params, current_human)

  defp staking_action("claim_regent", params, current_human),
    do: RegentStaking.claim_regent(params, current_human)

  defp staking_action("claim_and_restake_regent", params, current_human),
    do: RegentStaking.claim_and_restake_regent(params, current_human)

  defp staking_action(_action, _params, _current_human), do: {:error, :invalid_action}

  defp staking_pending_copy("stake"),
    do: "Open your wallet to confirm the staking transaction."

  defp staking_pending_copy("unstake"),
    do: "Open your wallet to confirm the unstake transaction."

  defp staking_pending_copy("claim_usdc"),
    do: "Open your wallet to confirm the USDC claim."

  defp staking_pending_copy("claim_regent"),
    do: "Open your wallet to confirm the REGENT claim."

  defp staking_pending_copy("claim_and_restake_regent"),
    do: "Open your wallet to confirm the claim-and-restake transaction."

  defp staking_pending_copy(_action), do: "Open your wallet to confirm the staking transaction."

  defp staking_success_copy("stake"), do: "Stake sent. Refreshing your staking snapshot."
  defp staking_success_copy("unstake"), do: "Unstake sent. Refreshing your staking snapshot."

  defp staking_success_copy("claim_usdc"),
    do: "USDC claim sent. Refreshing your staking snapshot."

  defp staking_success_copy("claim_regent"),
    do: "REGENT claim sent. Refreshing your staking snapshot."

  defp staking_success_copy("claim_and_restake_regent"),
    do: "Claim-and-restake sent. Refreshing your staking snapshot."

  defp staking_success_copy(_action), do: "Transaction sent. Refreshing your staking snapshot."

  defp staking_value(nil), do: "--"
  defp staking_value(value) when is_binary(value), do: value
  defp staking_value(value), do: to_string(value)

  defp holder_percent_width(percent) when is_binary(percent) do
    String.trim_trailing(percent, "%") <> "%"
  end

  defp holder_percent_width(_percent), do: "0%"

  defp staking_notice_class(:success) do
    "border-[color:color-mix(in_oklch,var(--positive)_55%,var(--border)_45%)] bg-[color:color-mix(in_oklch,var(--positive)_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp staking_notice_class(:error) do
    "border-[color:#a6574f] bg-[color:color-mix(in_oklch,#a6574f_10%,transparent)] text-[color:var(--foreground)]"
  end

  defp staking_notice_class(_tone) do
    "border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_90%,transparent)] text-[color:var(--foreground)]"
  end
end
