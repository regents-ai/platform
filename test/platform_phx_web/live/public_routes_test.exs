defmodule PlatformPhxWeb.PublicRoutesTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Repo

  test "home route exposes social share metadata", %{conn: conn} do
    html =
      conn
      |> get("/")
      |> html_response(200)

    share_description =
      "Autolaunch and Techtree let your Claws and Hermes do more, run a business, and advance the tech trees of the world."

    share_image_url = PlatformPhxWeb.Endpoint.url() <> "/images/og-image.png"

    assert html =~ ~s(<meta name="description" content="#{share_description}")
    assert html =~ ~s(<meta property="og:title" content="Regents Labs")
    assert html =~ ~s(<meta property="og:description" content="#{share_description}")
    assert html =~ ~s(<meta property="og:image" content="#{share_image_url}")
    assert html =~ ~s(<meta name="twitter:card" content="summary_large_image")
    assert html =~ ~s(<meta name="twitter:image" content="#{share_image_url}")
    assert html =~ ~s(<link rel="manifest" href="/site.webmanifest")

    assert html =~
             ~s(<link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png")

    assert html =~
             ~s(<link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32x32.png")
  end

  test "site web manifest is served", %{conn: conn} do
    body =
      conn
      |> get("/site.webmanifest")
      |> response(200)

    assert body =~ "\"name\": \"Regent Platform\""
    assert body =~ "\"src\": \"/images/android-chrome-512x512.png\""
  end

  test "home route renders", %{conn: conn} do
    {:ok, _home, html} = live(conn, "/")

    assert html =~ "Regents Labs"
    assert html =~ "$REGENT"
    assert html =~ "platform-home-shell"
    assert html =~ "home-voxel-background"
    assert html =~ "data-voxel-background=\"home\""
    assert html =~ "entry-card-surface-techtree-home"
    assert html =~ "entry-card-surface-autolaunch-home"
    assert html =~ "entry-card-surface-dashboard-home"
    assert html =~ "/images/techtree-logo.png"
    assert html =~ "/images/autolaunch-logo.png"
    assert html =~ "/images/regents-logo.png"
    assert html =~ "https://x.com/regents_sh"
    assert html =~ "https://farcaster.xyz/regent"
    assert html =~ "https://discord.gg/regents"
    assert html =~ "https://github.com/orgs/regent-ai/repositories"

    assert html =~
             "https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"

    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "data-color-mode-cycle"
    assert html =~ "aria-label=\"Research\""
    assert html =~ "aria-label=\"Revenue\""
    assert html =~ "aria-label=\"Open\""
    assert html =~ "href=\"/services\""
    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "Choose where to work next."
    assert html =~ "Go to services, billing, and company launches."
    assert html =~ "Publish work that other agents can inspect, rerun, and improve."
    assert html =~ "https://huggingface.co/datasets/nvidia/Nemotron-RL-bixbench_hypothesis"
    assert html =~ "BBH-Train"
    assert html =~ "Raise launch capital for useful agents"
    assert html =~ "Community links, source, and token market"
    refute html =~ "layout-wallet-control-desktop"
    refute html =~ "layout-wallet-control-mobile"
  end

  test "www host renders the main home page instead of the missing subdomain state", %{
    conn: %Plug.Conn{} = conn
  } do
    conn = %{conn | host: "www.regents.sh"}
    {:ok, _home, html} = live(conn, "/")

    assert html =~ "Regents Labs"
    assert html =~ "platform-home-shell"
    assert html =~ "entry-card-surface-dashboard-home"
    refute html =~ "Subdomain not live yet"
    refute html =~ "Nothing is published at"
  end

  test "demo route renders", %{conn: conn} do
    {:ok, _demo, html} = live(conn, "/demo")

    assert html =~ "platform-demo-shell"
    assert html =~ "platform-demo-stage"
    assert html =~ "demo-surface-techtree"
    assert html =~ "demo-surface-dashboard"
    assert html =~ "demo-surface-autolaunch"
    assert html =~ "Regents voxel demo"
  end

  test "demo2 route renders", %{conn: conn} do
    {:ok, _demo, html} = live(conn, "/demo2")

    assert html =~ "platform-demo2-shell"
    assert html =~ "platform-demo2-frame-ember-hall"
    assert html =~ "platform-demo2-frame-redline"
    assert html =~ "phx-hook=\"Demo2Tunnel\""
    assert html =~ "platform-demo2-scene-ember-hall"
    assert html =~ "Five full-height tunnel passes"
    assert html =~ "Wide ember hall"
    assert html =~ "Redline"
  end

  test "overview route renders", %{conn: conn} do
    {:ok, _overview, html} = live(conn, "/overview")

    assert html =~ "See how the platform fits together"
    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "See how people and agents move through Regents."
    assert html =~ "Human Overview"
    assert html =~ "Agent Overview"
    assert html =~ "Using Regents as a human operator"
    assert html =~ "Regents is for a Claw/Hermes-type agent to flourish"
    assert html =~ "npm install -g @regentlabs/cli"
    assert html =~ "Install the shared operator rail"
    assert html =~ "Keep the Techtree skill path close"
    assert html =~ "Keep the Autolaunch skill path close"
    assert html =~ "access opens"
    assert html =~ "Visit techtree.sh"
    assert html =~ "Visit autolaunch.sh"
    assert html =~ "https://techtree.sh"
    assert html =~ "https://autolaunch.sh"
    assert html =~ "phx-hook=\"OverviewMode\""
    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "data-mode=\"human\""
    assert html =~ "platform-overview-human-scene"
    assert html =~ "platform-overview-agent-scene"
    assert html =~ "Get Oriented"
    assert html =~ "Build and Operate"
  end

  test "overview route accepts regent scene lifecycle events", %{conn: conn} do
    {:ok, overview, _html} = live(conn, "/overview")

    assert render_hook(overview, "regent:surface_ready", %{
             "active_face" => "entry",
             "rendered_targets" => 1,
             "scene_version" => 2
           }) =~ "platform-overview-human-scene"

    assert render_hook(overview, "regent:surface_error", %{
             "message" => "test"
           }) =~ "platform-overview-agent-scene"
  end

  test "services route renders", %{conn: conn} do
    {:ok, _services, html} = live(conn, "/services")

    assert html =~ "Services"
    assert html =~ "Manage names, redemptions, and wallet setup"
    assert html =~ "Handle the shared setup work first"
    assert html =~ "Claim your Regent identity"
    assert html =~ "Redeem an Animata pass for REGENT"
    assert html =~ "https://news.regents.sh"
    assert html =~ "Community"
    assert html =~ "https://x.com/regents_sh"
    assert html =~ "https://farcaster.xyz/regent"
    assert html =~ "https://discord.gg/regents"
    assert html =~ "https://github.com/orgs/regent-ai/repositories"

    assert html =~
             "https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"

    assert html =~ "phx-hook=\"SidebarCommunity\""
    assert html =~ "dashboard-voxel-background"
    assert html =~ "data-voxel-background=\"dashboard\""
    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "services-wallet-console"
    assert html =~ "phx-hook=\"DashboardPrivyBridge\""
    assert html =~ "phx-hook=\"DashboardWallet\""
    assert html =~ "layout-wallet-control-desktop"
    assert html =~ "data-wallet-signed-in=\"false\""
    assert html =~ "Sign In"
    assert html =~ "phx-hook=\"DashboardNameClaim\""
    assert html =~ "phx-hook=\"DashboardRedeem\""
    assert html =~ "Shared services"
    assert html =~ "Launch flow"

    assert html =~
             "Use this page to review wallet holdings, claim names, redeem passes, and prepare the account for Agent Formation."

    refute html =~ "dashboard-root"
  end

  test "agent formation route renders", %{conn: conn} do
    {:ok, _formation, html} = live(conn, "/agent-formation")

    assert html =~ "Agent Formation"
    assert html =~ "Move from a claimed name to a live company"
    assert html =~ "agent-formation-wallet-console"
    assert html =~ "Names tied to this wallet"
    assert html =~ "Passes Owned"
    assert html =~ "Regents Club"
    assert html =~ "https://opensea.io/collection/regents-club"
    assert html =~ "phx-hook=\"DashboardPrivyBridge\""
    assert html =~ "phx-hook=\"DashboardWallet\""
    assert html =~ "layout-wallet-control-desktop"
    assert html =~ "data-wallet-signed-in=\"false\""
    assert html =~ "Sign In"

    assert html =~
             "Review your wallet, choose one of your claimed names, and take it live once billing is ready."

    refute html =~ "dashboard-root"
  end

  test "subdomain root renders the published agent page", %{
    conn: %Plug.Conn{} = conn
  } do
    conn = %{conn | host: "solidity.regents.sh"}
    {:ok, _home, html} = live(conn, "/")

    assert html =~ "Solidity Regent"
    assert html =~ "Regent company"
    assert html =~ "Ways to work with this company"
    assert html =~ "Public work feed"
    assert html =~ "solidity.agent.base.eth"
    assert html =~ "solidity.regent.eth"
    assert html =~ "This page is the public home for the company."
    assert html =~ "Treasury Router audit"
    assert html =~ "Company room"

    assert html =~
             "Join the room to ask questions, follow updates, and keep the company conversation in one place."

    refute html =~ "https://solidity.sprites.dev"
  end

  test "signed-in owner sees company controls on the public company page", %{conn: conn} do
    human = insert_human!("0xowner111111111111111111111111111111111111")
    _billing = insert_billing_account!(human, 700)
    _agent = insert_public_agent!(human, "owner-control")

    conn = %{conn | host: "owner-control.regents.sh"}

    {:ok, view, html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/")

    assert html =~ "Owner controls"
    assert html =~ "Manage your company from here"
    assert html =~ "Runtime balance"
    assert html =~ "Owner admin"
    assert has_element?(view, "#agent-owner-pause")

    pause_html =
      view
      |> element("#agent-owner-pause")
      |> render_click()

    assert pause_html =~ "Company paused."
    assert has_element?(view, "#agent-owner-resume")

    resume_html =
      view
      |> element("#agent-owner-resume")
      |> render_click()

    assert resume_html =~ "Company running again."
    assert has_element?(view, "#agent-owner-pause")
  end

  test "company room lets the owner join and post from the company page", %{conn: conn} do
    human = insert_human!("0xowner222222222222222222222222222222222222")
    agent = insert_public_agent!(human, "owner-room")
    room_key = PlatformPhx.Xmtp.company_room_key(agent)

    on_exit(fn ->
      PlatformPhx.Xmtp.reset_for_test!(room_key)
    end)

    conn = %{conn | host: "owner-room.regents.sh"}

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/")

    initial_html = render(view)

    html =
      if has_element?(view, "#company-room [phx-click=\"xmtp_join\"]") do
        view
        |> element("#company-room [phx-click=\"xmtp_join\"]")
        |> render_click()
      else
        initial_html
      end

    [_, request_id] =
      Regex.run(~r/data-pending-request-id="([^"]+)"/, html) ||
        Regex.run(~r/data-pending-request-id="([^"]+)"/, initial_html) ||
        flunk("expected a pending join request in the company room")

    html =
      view
      |> element("#company-room")
      |> render_hook("xmtp_join_signature_signed", %{
        "request_id" => request_id,
        "signature" => "0xsigned"
      })

    assert html =~ "You are in the room."

    html =
      view
      |> form("#company-room-form", %{
        "xmtp_room" => %{"body" => "Owner update from the company page."}
      })
      |> render_submit()

    assert html =~ "Owner update from the company page."
    assert html =~ "Owner admin"
  end

  test "shader route renders", %{conn: conn} do
    {:ok, _shader, html} = live(conn, "/shader")

    assert html =~ "Shader registry"
    assert html =~ "Browse shared shader work"
    assert html =~ "Shader"
    assert html =~ "shader-root"
    assert html =~ "phx-hook=\"ShaderRoot\""
    assert html =~ "platform-layout-root"
    assert html =~ "platform-footer-voxel-classic"
  end

  test "token card route renders hosted card shell", %{conn: conn} do
    conn =
      conn
      |> get("/cards/regents-club/1")

    html = html_response(conn, 200)
    share_url = PlatformPhxWeb.Endpoint.url() <> "/cards/regents-club/1"
    share_image_url = PlatformPhxWeb.Endpoint.url() <> "/images/animata/cards/1.png"

    assert html =~ "regents-token-card-page"
    assert html =~ "data-token-card-root"
    assert html =~ "\"tokenId\":1"
    assert html =~ "\"shaderId\":"
    assert html =~ "Regents Club #1"
    assert html =~ ~s(<meta property="og:title" content="Regents Club #1")
    assert html =~ ~s(<meta property="og:url" content="#{share_url}")
    assert html =~ ~s(<meta property="og:image" content="#{share_image_url}")
    assert html =~ ~s(<meta name="twitter:image" content="#{share_image_url}")
    assert html =~ ~s(<link rel="canonical" href="#{share_url}")

    assert get_resp_header(conn, "x-frame-options") == []

    assert get_resp_header(conn, "content-security-policy") == [
             "frame-ancestors 'self' https://opensea.io https://*.opensea.io;"
           ]
  end

  test "token card image is served from the hosted card path", %{conn: conn} do
    conn =
      conn
      |> get("/images/animata/cards/1.png")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "token card route returns not found for unknown token", %{conn: conn} do
    conn
    |> get("/cards/regents-club/99999")
    |> response(404)
  end

  test "metadata route returns token metadata json", %{conn: conn} do
    payload =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/metadata/615")
      |> json_response(200)

    assert payload["name"] == "Regents Club #615"
    assert payload["image"] == "https://regents.sh/images/animata/cards/615.png"
    assert payload["animation_url"] == "https://regents.sh/cards/regents-club/615"
  end

  test "metadata route returns not found for unknown token", %{conn: conn} do
    conn
    |> put_req_header("accept", "application/json")
    |> get("/metadata/99999")
    |> response(404)
  end

  test "heerich demo route renders", %{conn: conn} do
    {:ok, _demo, html} = live(conn, "/heerich-demo")

    assert html =~ "Heerich 0.11.0 Lab"
    assert html =~ "platform-heerich-demo-shell"
    assert html =~ "demo-explode-cluster"
    assert html =~ "addGeometry(type: fill)"
    assert html =~ "applyStyle(type: box / line)"
  end

  test "logos route renders", %{conn: conn} do
    {:ok, _logos, html} = live(conn, "/logos")

    assert html =~ "Four study families, sixteen voxel reads each, one live theme switch."
    assert html =~ "platform-logo-root"
    assert html =~ "platform-logo-section-regents"
    assert html =~ "platform-logo-section-autolaunch"
    assert html =~ "Download PNG"
    assert html =~ "Download SVG"
  end

  test "techtree route renders", %{conn: conn} do
    {:ok, _techtree, html} = live(conn, "/techtree")

    assert html =~ "Research surface"
    assert html =~ "Publish work other agents can inspect"
    assert html =~ "Techtree"
    assert html =~ "Agent Skill"
    assert html =~ "Techtree gives agents a public graph for open autoresearch."
    assert html =~ "notebook, eval, harness, skill, trace"
    assert html =~ "replicable Python notebooks on marimo.io"
    assert html =~ "open data and code on IPFS"
    assert html =~ "Edison Scientific and Nvidia"
    assert html =~ "https://edisonscientific.com/articles/accelerating-science-at-scale"
    assert html =~ "Linked tools, runtimes, research surfaces, and platforms behind Techtree."
    assert html =~ "Privy"
    assert html =~ "IPFS"
    assert html =~ "Ethereum"
    assert html =~ "Base"
    assert html =~ "https://openclaw.sh"
    assert html =~ "https://elixir-lang.org"
    assert html =~ "https://www.phoenixframework.org"
    assert html =~ "https://privy.io"
    assert html =~ "https://ipfs.io"
    assert html =~ "https://ethereum.org"
    assert html =~ "https://base.org"
    assert html =~ "Techtree is live at techtree.sh."
    assert html =~ "regent techtree start"
    assert html =~ "regent techtree autoskill publish skill"
    assert html =~ "regent techtree bbh capsules list"
    assert html =~ "Open techtree.sh"
    assert html =~ "https://github.com/regent-ai/techtree"
    assert html =~ "https://techtree.sh"
    assert html =~ "[Techtree skill.md coming soon]"
    assert html =~ "Open the live Techtree surface, or inspect the repo that backs it."
    refute html =~ "Copy prompt"
    refute html =~ "Why this surface exists"
    refute html =~ "platform-techtree-surface"
  end

  test "autolaunch route renders", %{conn: conn} do
    {:ok, _autolaunch, html} = live(conn, "/autolaunch")

    assert html =~ "Capital surface"
    assert html =~ "Raise backing for useful agent work"
    assert html =~ "Autolaunch"
    assert html =~ "Agent Skill"
    assert html =~ "Autolaunch helps agents raise capital before they scale."
    assert html =~ "Uniswap CCA auctions"
    assert html =~ "revsplit contract"
    assert html =~ "ERC-8004 registration"
    assert html =~ "Linked tools, runtimes, agent surfaces, and platforms behind Autolaunch."
    assert html =~ "Privy"
    assert html =~ "IPFS"
    assert html =~ "Ethereum"
    assert html =~ "Base"
    assert html =~ "Autolaunch is live at autolaunch.sh."
    assert html =~ "regent autolaunch prelaunch wizard"
    assert html =~ "regent autolaunch launch finalize"
    assert html =~ "regent autolaunch trust x-link --agent &lt;id&gt;"
    assert html =~ "Open autolaunch.sh"
    assert html =~ "https://github.com/regent-ai/autolaunch"
    assert html =~ "https://autolaunch.sh"
    assert html =~ "[Autolaunch skill.md coming soon]"
    refute html =~ "Copy prompt"
    assert html =~ "https://openclaw.sh"
    assert html =~ "https://elixir-lang.org"
    assert html =~ "https://www.phoenixframework.org"
    assert html =~ "https://privy.io"
    assert html =~ "https://ipfs.io"
    assert html =~ "https://ethereum.org"
    assert html =~ "https://base.org"
    refute html =~ "Why this surface exists"
    refute html =~ "platform-autolaunch-surface"
  end

  test "regent cli route renders", %{conn: conn} do
    {:ok, _regent_cli, html} = live(conn, "/regent-cli")

    assert html =~ "Terminal rail"
    assert html =~ "Work with Regents from the command line"
    assert html =~ "Regent CLI"
    assert html =~ "Copy page as markdown"
    assert html =~ "Local runtime and operator surface for"
    assert html =~ "@regentlabs/cli"
    assert html =~ "regent create init"
    assert html =~ "regent create wallet --write-env"
    assert html =~ "regent techtree start"
    assert html =~ "regent auth siwa login"
    assert html =~ "The CLI is JSON-first."
    assert html =~ "Use `--session-file /absolute/path.json`"
    assert html =~ "regent chatbox history --webapp|--agent"
    assert html =~ "CLI posting is agent-room only."

    assert html =~
             "regent platform auth login --identity-token-env REGENT_PLATFORM_IDENTITY_TOKEN"

    assert html =~ "regent platform company create --claimed-label &lt;label&gt;"
    assert html =~ "regent autolaunch ..."
    assert html =~ "regent shader list"
    assert html =~ "regent shader export w3dfWN --out avatars/shard.png"
  end

  test "token info route renders", %{conn: conn} do
    {:ok, token_info, html} = live(conn, "/token-info")

    assert html =~ "Token Purpose"
    assert html =~ "$REGENT is staked to earn your share of protocol revenue."
    assert html =~ "The majority of revenue is used to buyback $REGENT."
    assert html =~ "Market Cap"
    assert html =~ "FDV"
    assert html =~ "$REGENT is live on Base"

    assert html =~ "Revenue token"
    assert html =~ "Understand how REGENT flows through the platform"

    assert html =~
             "https://app.uniswap.org/explore/tokens/base/0x6f89bca4ea5931edfcb09786267b251dee752b07?inputCurrency=NATIVE"

    assert html =~
             "https://www.geckoterminal.com/base/pools/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"

    assert html =~
             "https://dexscreener.com/base/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"

    assert html =~ "View on Uniswap"
    assert html =~ "View on GeckoTerminal"
    assert html =~ "View on Dexscreener"
    assert html =~ "Autolaunch"
    assert html =~ "Techtree"
    assert html =~ "$REGENT staking emissions"
    assert html =~ "20% yield for initial year"
    assert html =~ "The staking portal and emission claims will open through Autolaunch"
    assert html =~ "pp-token-fee-highlight"
    assert html =~ "agent token&#39;s trading fees from the Uniswap v4 fee hook"
    assert html =~ "raised USDC in CCA auctions."
    assert html =~ "Stablecoin Revenues"
    assert html =~ "Regents Platform"
    assert html =~ "Stake $REGENT in the protocol revsplit contract."
    assert html =~ "Claim your stablecoin share of Regent Labs revenue anytime."

    assert html =~ "80% or more of protocol skim will go to buybacks."

    assert html =~
             "Openclaw and Hermes agent hosting, with Stripe LLM billing for margin fees on hosted Regents."

    assert html =~ "Where revenue enters the system"
    assert html =~ "Token Holders"
    assert html =~ "Snapshot of largest token locks, pools, and holders"

    assert html =~
             "As of 4/1/2026 the large majority of tokens are locked or held by the following 6 addresses."

    assert html =~ "0x8E84...DF6C"
    assert html =~ "0x46F4...C002"
    assert html =~ "7th through 2,208th: Regent Community Members!"
    assert html =~ "Regent Token Allocations and Uses"
    assert html =~ "20% to Clanker Deployment"
    assert html =~ "40% Regents Labs Multisig"
    assert html =~ "40% Clanker Vault - Locked onchain for 1 year then vesting over 2 years"
    assert html =~ "20% Clanker public + 40% growth emissions + 40% long-term incentives."
    assert html =~ "Sovereign Agent Incentives"
    refute html =~ "token for all platforms"
    refute html =~ "All Regents Labs product value flows to $REGENT"
    refute html =~ "Click a row to open the holder drawer."
    refute html =~ "40% airdrop to Regent Labs multisig for the following:"

    unknown_holder_html =
      token_info
      |> element("button[phx-value-rank=\"5\"]")
      |> render_click()

    assert unknown_holder_html =~ "Unknown holder who accumulated 2.5% of supply"
    refute unknown_holder_html =~ "View multichain wallet"
  end

  test "removed routes return 404", %{conn: conn} do
    for path <- ["/home", "/names", "/redeem", "/settings", "/agents", "/dashboard"] do
      response = get(recycle(conn), path)
      assert response.status == 404
    end
  end

  defp insert_human!(wallet_address) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      display_name: "owner@regents.sh"
    })
    |> Repo.insert!()
  end

  defp insert_billing_account!(human, balance_cents) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      stripe_pricing_plan_subscription_id: "sub_#{System.unique_integer([:positive])}",
      billing_status: "active",
      runtime_credit_balance_usd_cents: balance_cents
    })
    |> Repo.insert!()
  end

  defp insert_public_agent!(human, slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        template_key: "start",
        name: "Owner Control Regent",
        slug: slug,
        claimed_label: slug,
        basename_fqdn: "#{slug}.agent.base.eth",
        ens_fqdn: "#{slug}.regent.eth",
        status: "published",
        public_summary: "A company page for launch-flow testing.",
        hero_statement: "The owner should be able to manage this company from its home page.",
        runtime_status: "ready",
        checkpoint_status: "ready",
        stripe_llm_billing_status: "active",
        stripe_customer_id: "cus_owner_control",
        stripe_pricing_plan_subscription_id: "sub_owner_control",
        sprite_free_until: DateTime.add(now, 86_400, :second),
        sprite_metering_status: "paid",
        wallet_address: human.wallet_address,
        published_at: now,
        desired_runtime_state: "active",
        observed_runtime_state: "active"
      })
      |> Repo.insert!()

    %Subdomain{}
    |> Subdomain.changeset(%{
      agent_id: agent.id,
      slug: slug,
      hostname: "#{slug}.regents.sh",
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      active: true
    })
    |> Repo.insert!()

    agent
  end
end
