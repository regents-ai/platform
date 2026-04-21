defmodule PlatformPhxWeb.PublicRoutesTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Artifact
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.OperatorReports
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig

  test "home route exposes social share metadata", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)

    share_description =
      "The Regent website guides wallet setup, company launch, and public company pages, while Regents CLI handles local Techtree and Autolaunch work."

    canonical_url = "http://#{conn.host}/"
    share_image_url = "http://#{conn.host}/images/og-image.png"

    assert html =~ ~s(<meta name="description" content="#{share_description}")
    assert html =~ ~s(<meta property="og:title" content="Regents Labs")
    assert html =~ ~s(<meta property="og:description" content="#{share_description}")
    assert html =~ ~s(<link rel="canonical" href="#{canonical_url}")
    assert html =~ ~s(<meta property="og:url" content="#{canonical_url}")
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
    {:ok, view, html} = live(conn, "/")

    assert html =~ "Regents Labs"
    assert html =~ "platform-home-shell"
    assert html =~ "home-voxel-background"
    assert html =~ "data-voxel-background=\"home\""
    assert html =~ "/images/regents-logo.png"
    assert html =~ "Form your agent company."
    assert html =~ "pnpm add -g @regentslabs/cli"
    assert html =~ "Open app"
    assert html =~ "View CLI"
    refute html =~ "Three-step story"
    assert html =~ "The path"
    assert html =~ "What this page gives you"
    assert html =~ "Improve the agent in Techtree. Fund it in Autolaunch."
    assert html =~ "href=\"/docs\""
    assert html =~ "href=\"/cli\""
    assert html =~ "href=\"/app\""
    assert html =~ "https://x.com/regents_sh"
    assert html =~ "https://farcaster.xyz/regent"
    assert html =~ "https://discord.gg/regents"
    assert html =~ "https://github.com/orgs/regents-ai/repositories"
    refute html =~ "layout-wallet-control-floating"
    refute html =~ "Sign In"

    assert has_element?(view, "#home-primary-cta")
    assert has_element?(view, "#home-nav-open-app")
    assert html =~ "platform-footer-voxel-classic"
    assert html =~ "data-color-mode-cycle"

    refute html =~ "layout-wallet-control-desktop"
    refute html =~ "layout-wallet-control-mobile"
  end

  test "docs route renders in app", %{conn: conn} do
    {:ok, _docs, html} = live(conn, "/docs")

    assert html =~ "platform-docs-shell"
    assert html =~ "Use this page when you want the short version of the Regent story."
    assert html =~ "The website is for guided setup and company launch."
    assert html =~ "href=\"/app\""
    assert html =~ "href=\"/cli\""
    assert html =~ "href=\"/techtree\""
    assert html =~ "href=\"/autolaunch\""
    assert html =~ "href=\"/docs\""
  end

  test "www host renders the main home page instead of the missing subdomain state", %{
    conn: %Plug.Conn{} = conn
  } do
    conn = %{conn | host: "www.regents.sh"}
    {:ok, _home, html} = live(conn, "/")

    assert html =~ "Regents Labs"
    assert html =~ "platform-home-shell"
    assert html =~ "Form your agent company."
    refute html =~ "Subdomain not active"
    refute html =~ "No published agent lives on this host yet."
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

  test "app access route renders", %{conn: conn} do
    {:ok, _access, html} = live(conn, "/app/access")

    assert html =~ "App setup"
    assert html =~ "Check access"
    assert html =~ "Check whether this wallet can open a company."
    assert html =~ "Redeem a pass"
    assert html =~ "Current blocker"
    assert html =~ "phx-hook=\"DashboardPrivyBridge\""
    assert html =~ "phx-hook=\"DashboardWallet\""
    assert html =~ "phx-hook=\"DashboardRedeem\""
    assert html =~ "OpenSea"
  end

  test "app identity route renders clear claim guidance", %{conn: conn} do
    {:ok, _identity, html} = live(conn, "/app/identity")

    assert html =~ "App setup"
    assert html =~ "Claim identity"
    assert html =~ "Current blocker"
    assert html =~ "What you can do now"
    assert html =~ "Enter a name"
    assert html =~ "Snapshot claim"
    assert html =~ "Public claim"
  end

  test "app billing route renders a blocker when name setup is missing", %{conn: conn} do
    {:ok, _billing, html} = live(conn, "/app/billing")

    assert html =~ "App setup"
    assert html =~ "Add billing after a name is ready."
    assert html =~ "Sign in first, then claim a name before adding billing."
    assert html =~ "Go to access"
    refute html =~ "app-billing-form"
  end

  test "app formation route renders", %{conn: conn} do
    {:ok, _formation, html} = live(conn, "/app/formation")

    assert html =~ "App setup"
    assert html =~ "Open company"
    assert html =~ "Sign in first so this wallet can be checked."
    assert html =~ "Go to access"
    refute html =~ "app-formation-form"
  end

  test "app provisioning route renders a clear not-found state", %{conn: conn} do
    {:ok, _provisioning, html} = live(conn, "/app/provisioning/test-id")

    assert html =~ "App setup"
    assert html =~ "Opening company"
    assert html =~ "We could not find that company opening."
    assert html =~ "This link no longer matches an active company opening."
    assert html =~ "Back to formation"
  end

  test "cli route renders", %{conn: conn} do
    {:ok, _cli, html} = live(conn, "/cli")

    canonical_html =
      conn
      |> get("/cli")
      |> html_response(200)

    assert html =~ "Regents CLI"
    assert html =~ "Use Regents CLI when the work starts on your machine."
    assert html =~ "Copy page as markdown"
    assert html =~ "pnpm add -g @regentslabs/cli"
    assert html =~ "regent techtree start"

    assert html =~
             "Use the website for guided setup. Use the CLI for local work and repeatable runs."

    assert canonical_html =~ ~s(<link rel="canonical" href="http://www.example.com/cli")
    assert canonical_html =~ ~s(<meta property="og:url" content="http://www.example.com/cli")
  end

  test "bug report ledger renders anonymous public submissions cleanly", %{conn: conn} do
    assert {:ok, _report} =
             OperatorReports.create_bug_report(%{
               "summary" => "Anonymous summary",
               "details" => "Anonymous details"
             })

    {:ok, _view, html} = live(conn, "/bug-report")

    assert html =~ "Anonymous public report"
    assert html =~ "Sent from the public bug report form"
    assert html =~ "No wallet was attached to this report."
    assert html =~ "This report came through the public form."
    refute html =~ "token ·"
  end

  test "subdomain root renders the published agent page", %{
    conn: %Plug.Conn{} = conn
  } do
    conn = %{conn | host: "solidity.regents.sh"}
    {:ok, _home, html} = live(conn, "/")

    canonical_html =
      conn
      |> get("/")
      |> html_response(200)

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
    assert canonical_html =~ ~s(<link rel="canonical" href="http://solidity.regents.sh/")
    assert canonical_html =~ ~s(<meta property="og:url" content="http://solidity.regents.sh/")
  end

  test "agent route renders the published agent page without wallet chrome", %{conn: conn} do
    human = insert_human!("0xowner333333333333333333333333333333333333")
    agent = insert_public_agent!(human, "public-output-test")

    insert_public_artifact!(agent, %{
      title: "Public output",
      summary: "Public output",
      url: "https://public-output-test.regents.sh/",
      visibility: "public"
    })

    {:ok, _agent, html} = live(conn, "/agents/public-output-test")

    assert html =~ "Owner Control Regent"
    assert html =~ "agent-site-preview-shell"
    assert html =~ "Regent company"
    assert html =~ "Company room"
    assert html =~ "href=\"/agents/public-output-test\""
    refute html =~ "href=\"https://public-output-test.regents.sh/\""
    refute html =~ "layout-wallet-control-desktop"
    refute html =~ "layout-wallet-control-mobile"
  end

  test "signed-in owner sees company controls on the public company page", %{conn: conn} do
    previous_sprite_runtime_client = Application.get_env(:platform_phx, :sprite_runtime_client)

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientFake
    )

    on_exit(fn ->
      case previous_sprite_runtime_client do
        nil -> Application.delete_env(:platform_phx, :sprite_runtime_client)
        value -> Application.put_env(:platform_phx, :sprite_runtime_client, value)
      end
    end)

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

    assert html =~ "Shader Registry"
    assert html =~ "Shader"
    assert html =~ "shader-root"
    assert html =~ "phx-hook=\"ShaderRoot\""
    assert html =~ "platform-layout-root"
    assert html =~ "platform-footer-voxel-classic"
  end

  test "browser routes emit enforced csp and script nonce", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)
    [csp] = get_resp_header(conn, "content-security-policy")
    [_, header_nonce] = Regex.run(~r/script-src 'nonce-([^']+)'/, csp)
    [_, html_nonce] = Regex.run(~r/<script nonce=\"([^\"]+)\">/, html)

    assert csp =~ "default-src 'self';"
    assert csp =~ "script-src 'nonce-"
    assert csp =~ "https://challenges.cloudflare.com"
    assert csp =~ "style-src 'self' 'unsafe-inline';"

    assert csp =~
             "img-src 'self' data: blob: https://pbs.twimg.com https://explorer-api.walletconnect.com;"

    assert csp =~ "frame-ancestors 'none';"

    assert csp =~
             "child-src https://auth.privy.io https://verify.walletconnect.com https://verify.walletconnect.org;"

    assert csp =~
             "frame-src https://auth.privy.io https://verify.walletconnect.com https://verify.walletconnect.org https://oauth.telegram.org https://challenges.cloudflare.com;"

    assert csp =~ "connect-src 'self'"
    assert csp =~ "https://auth.privy.io"
    assert csp =~ "https://oauth.telegram.org"
    assert csp =~ "wss://relay.walletconnect.com"
    assert csp =~ "wss://www.walletlink.org"
    assert csp =~ connect_origin(RuntimeConfig.base_rpc_url())
    refute csp =~ "http://localhost:4000"
    refute csp =~ "connect-src *"
    assert header_nonce == html_nonce
  end

  test "token card route renders hosted card shell", %{conn: conn} do
    conn =
      conn
      |> get("/cards/regents-club/1")

    html = html_response(conn, 200)

    assert html =~ "regents-token-card-page"
    assert html =~ "data-token-card-root"
    assert html =~ "data-token-card-entry="
    assert html =~ "Regents Club #1"
    refute html =~ "data-token-card-json"
    refute html =~ "<script id=\"regents-token-card-json\""

    assert get_resp_header(conn, "x-frame-options") == []

    [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ "default-src 'self';"
    assert csp =~ "script-src 'nonce-"
    assert csp =~ "frame-ancestors 'self' https://opensea.io https://*.opensea.io;"
    assert csp =~ "connect-src 'self'"
    assert csp =~ "https://auth.privy.io"
    assert csp =~ connect_origin(RuntimeConfig.base_rpc_url())
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
    {:ok, view, _html} = live(conn, "/heerich-demo")

    assert has_element?(
             view,
             "#platform-heerich-shell-background[phx-hook=\"Demo2Tunnel\"][data-demo2-layout=\"shell\"][data-demo2-variant=\"regent-shell\"]"
           )

    assert has_element?(view, "#platform-heerich-shell-route")
    assert has_element?(view, "#platform-heerich-shell-scene")
    assert has_element?(view, "#platform-heerich-shell-content")
    assert has_element?(view, ".pp-heerich-shell-panel-hero")
    assert render(view) =~ "A full-page Regent shell with the content held in the middle."
    refute render(view) =~ "platform-demo2-panel-ember-hall"
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

    assert html =~ "Shared Research and Eval Tree"
    assert html =~ "Techtree"
    assert html =~ "Agent Skill"

    assert html =~
             "Start with Regents CLI, then move into Techtree for research, review, and publishing."

    assert html =~ "regent techtree start"
    assert html =~ "actual research and publishing work lives"

    assert html =~
             "After the guided start, the usual next moves are reading the live tree, publishing work, or stepping into the BBH branch for local runs, replay, and public proof."

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
    assert html =~ "https://github.com/regents-ai/techtree"
    assert html =~ "https://techtree.sh"
    assert html =~ "/agent-skills/regents-cli.md"
    assert html =~ "Open the live Techtree site, or inspect the repo that runs it."
    refute html =~ "Copy prompt"
    refute html =~ "Why this surface exists"
    refute html =~ "platform-techtree-surface"
    refute html =~ "[Techtree skill.md coming soon]"
  end

  test "autolaunch route renders", %{conn: conn} do
    {:ok, _autolaunch, html} = live(conn, "/autolaunch")

    assert html =~ "Raise agent capital"
    assert html =~ "Autolaunch"
    assert html =~ "Agent Skill"
    assert html =~ "Turn agent edge into runway."
    assert html =~ "bring in aligned backers"
    assert html =~ "claims, staking, and revenue"
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
    assert html =~ "https://github.com/regents-ai/autolaunch"
    assert html =~ "https://autolaunch.sh"
    assert html =~ "/agent-skills/regents-cli.md"
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
    refute html =~ "[Autolaunch skill.md coming soon]"
  end

  test "regent cli route renders", %{conn: conn} do
    {:ok, _regents_cli, html} = live(conn, "/cli")

    assert html =~ "CLI"
    assert html =~ "Regents CLI"
    assert html =~ "Copy page as markdown"
    assert html =~ "Use Regents CLI when the work starts on your machine."
    assert html =~ "@regentslabs/cli"
    assert html =~ "regent create init"
    assert html =~ "regent create wallet --write-env"
    assert html =~ "regent techtree start"
    assert html =~ "regent auth siwa login"
    assert html =~ "The CLI is JSON-first."
    assert html =~ "Use the Regent website for guided account tasks"
    assert html =~ "regent chatbox history --webapp|--agent"
    assert html =~ "CLI posting is agent-room only."
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

    assert html =~ "Platform revenue token"
    assert html =~ "Agent economies"

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
    unique_suffix = "#{human.id}-#{System.unique_integer([:positive])}"

    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      stripe_customer_id: "cus_#{unique_suffix}",
      stripe_pricing_plan_subscription_id: "sub_#{unique_suffix}",
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

  defp insert_public_artifact!(agent, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      agent_id: agent.id,
      title: "Public output",
      summary: "Public output",
      url: "https://example.com/output",
      visibility: "public",
      published_at: now
    }

    %Artifact{}
    |> Artifact.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp connect_origin(nil), do: nil

  defp connect_origin(url) do
    uri = URI.parse(url)

    default_port =
      case uri.scheme do
        "https" -> 443
        _ -> 80
      end

    suffix =
      if is_nil(uri.port) or uri.port == default_port do
        ""
      else
        ":#{uri.port}"
      end

    "#{uri.scheme}://#{uri.host}#{suffix}"
  end
end
