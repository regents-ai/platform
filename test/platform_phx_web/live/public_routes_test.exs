defmodule PlatformPhxWeb.PublicRoutesTest do
  use PlatformPhxWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Artifact
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.OperatorReports
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhx.XMTPMirror
  alias PlatformPhx.XMTPMirror.Rooms
  alias PlatformPhx.XMTPMirror.XmtpMembershipCommand

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
    assert html =~ "Open the hosted Regent company here."
    assert html =~ "use Autolaunch when funding comes next."
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
    {:ok, docs, html} = live(conn, "/docs")

    assert html =~ "platform-docs-shell"
    assert html =~ "Start here"
    assert html =~ "Copy page as markdown"
    assert html =~ "Where to go next"
    assert html =~ "Quick links"
    assert html =~ "App setup"
    assert html =~ "href=\"/app\""
    assert html =~ "href=\"/cli\""
    assert html =~ "href=\"/techtree\""
    assert html =~ "href=\"/autolaunch\""
    assert html =~ "href=\"/bug-report\""
    assert html =~ "href=\"/app/dashboard\""
    refute html =~ "The Regent story, short version"
    assert has_element?(docs, "#platform-shell-sidebar")
    assert has_element?(docs, "#platform-shell-header-desktop")
    assert has_element?(docs, "#platform-shell-header-mobile")
    assert has_element?(docs, "#platform-docs-hero")
    assert has_element?(docs, "#platform-docs-index")
    assert has_element?(docs, "#platform-docs-quick-links")
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

  test "internal demo and design routes are not served", %{conn: conn} do
    for path <- ["/demo", "/heerich-demo", "/logos", "/shader"] do
      conn
      |> recycle()
      |> get(path)
      |> response(404)
    end
  end

  test "app access route renders", %{conn: conn} do
    {:ok, access, html} = live(conn, "/app/access")

    assert html =~ "App setup"
    assert html =~ "Check access"
    assert html =~ "Check whether this wallet can open a company."
    assert html =~ "Redeem a pass"
    assert html =~ "Current blocker"
    assert html =~ "phx-hook=\"DashboardPrivyBridge\""
    assert html =~ "phx-hook=\"DashboardWallet\""
    assert html =~ "phx-hook=\"DashboardRedeem\""
    assert html =~ "OpenSea"
    refute html =~ "Open app"
    assert has_element?(access, "#platform-shell-sidebar")
    assert has_element?(access, "#platform-shell-header-desktop")
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
    {:ok, cli, html} = live(conn, "/cli")

    canonical_html =
      conn
      |> get("/cli")
      |> html_response(200)

    assert html =~ "Regents CLI"
    assert html =~ "The local tool for working with the Regents platform."
    assert html =~ "Copy page as markdown"
    assert html =~ "pnpm add -g @regentslabs/cli"
    assert html =~ "regents techtree start"
    assert html =~ "App setup"
    assert html =~ "Go to App setup"
    assert has_element?(cli, "#platform-regents-cli-quick-start")
    assert has_element?(cli, "#platform-regents-cli-commands")
    assert has_element?(cli, "#platform-regents-cli-guidance")

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
    assert html =~ "No wallet attached"
    assert html =~ "Open"
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
    assert html =~ "Public company home"
    assert html =~ "Company profile"
    assert html =~ "Service menu"
    assert html =~ "Ways to work with this company"
    assert html =~ "Recent finished work"
    assert html =~ "How this company works"
    assert html =~ "Treasury Router audit"
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
    assert html =~ "Public company home"
    assert html =~ "Company at a glance"
    assert html =~ "Company room"
    assert html =~ "View all finished work"
    assert html =~ "Finished work"
    assert html =~ "layout-wallet-control-desktop"
    assert html =~ "layout-wallet-control-mobile"
  end

  test "signed-in owner sees company controls on the public company page", %{conn: conn} do
    previous_sprites_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    on_exit(fn ->
      case previous_sprites_client do
        nil -> Application.delete_env(:platform_phx, :runtime_registry_sprites_client)
        value -> Application.put_env(:platform_phx, :runtime_registry_sprites_client, value)
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
    assert html =~ "Work balance"
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

  test "public company page shows the saved avatar and keeps the gold border rule", %{conn: conn} do
    human =
      insert_human!("0xowner444444444444444444444444444444444444", %{
        avatar: %{
          "kind" => "collection_token",
          "collection" => "animataPass",
          "token_id" => 17,
          "preview_type" => "token_card",
          "gold_border" => true
        }
      })

    _agent = insert_public_agent!(human, "avatar-public")

    {:ok, _agent, html} = live(conn, "/agents/avatar-public")

    assert html =~ "Saved avatar"
    assert html =~ "Regents Club #17"
    assert html =~ "public avatar saved for this company"
  end

  test "company room lets the owner join and post from the company page", %{conn: conn} do
    human = insert_human!("0xowner222222222222222222222222222222222222")
    agent = insert_public_agent!(human, "owner-room")
    room_key = Rooms.company_room_key(agent)

    assert {:ok, room} =
             XMTPMirror.ensure_room(%{
               "room_key" => room_key,
               "xmtp_group_id" => "xmtp-#{room_key}-#{System.unique_integer([:positive])}",
               "name" => "#{agent.name} Room",
               "status" => "active",
               "presence_ttl_seconds" => 120,
               "capacity" => 200
             })

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

    assert html =~ "Your room seat is being prepared."

    command = Repo.get_by!(XmtpMembershipCommand, room_id: room.id, human_user_id: human.id)
    command |> Ecto.Changeset.change(status: "done") |> Repo.update!()
    send(view.pid, {:public_site_event, %{event: :xmtp_room_membership, room_key: room_key}})
    assert render(view) =~ "You are in the room."

    html =
      view
      |> form("#company-room-form", %{
        "xmtp_room" => %{"body" => "Owner update from the company page."}
      })
      |> render_submit()

    assert html =~ "Owner update from the company page."
    assert html =~ "You are in the room."
    assert html =~ "1 active now"
    assert html =~ "Owner admin"
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

  test "platform no longer serves token card images directly", %{conn: conn} do
    conn =
      conn
      |> get("/images/animata/cards/1.png")

    assert response(conn, 404)
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
    assert payload["image"] == "https://media.regents.sh/images/animata/cards/615.png"
    assert payload["animation_url"] == "https://regents.sh/cards/regents-club/615"
  end

  test "metadata route returns not found for unknown token", %{conn: conn} do
    conn
    |> put_req_header("accept", "application/json")
    |> get("/metadata/99999")
    |> response(404)
  end

  test "metadata route hides non-missing file errors", %{conn: conn} do
    previous_root = Application.fetch_env!(:platform_phx, :token_metadata_root)

    temp_root =
      Path.join(System.tmp_dir!(), "metadata-public-error-#{System.unique_integer([:positive])}")

    File.mkdir_p!(temp_root)
    File.write!(Path.join(temp_root, "broken"), "{not json")
    Application.put_env(:platform_phx, :token_metadata_root, temp_root)

    on_exit(fn ->
      Application.put_env(:platform_phx, :token_metadata_root, previous_root)
      File.rm_rf!(temp_root)
    end)

    body =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/metadata/broken")
      |> response(500)

    assert body == "Metadata is unavailable right now."
    refute body =~ "Jason"
    refute body =~ "%{"
    refute body =~ "{:"
  end

  test "techtree route renders", %{conn: conn} do
    {:ok, techtree, html} = live(conn, "/techtree")

    assert html =~ "Research • Review • Publish"
    assert html =~ "Techtree"
    assert html =~ "Regents CLI starts the setup."
    assert html =~ "reviewable"
    assert html =~ "publishable"
    assert html =~ "Open Techtree"
    assert html =~ "View CLI"
    assert html =~ "regents techtree start"
    assert html =~ "Purpose"
    assert html =~ "Tech stack"
    assert html =~ "Agent Skill"
    assert html =~ "Preview"
    assert html =~ "Primary skill: Research • Synthesis • Publishing"
    assert html =~ "CLI rails"
    assert html =~ "Everything you need to run Techtree from the terminal."
    assert html =~ "Start Techtree"
    assert html =~ "BBH-Train"
    assert html =~ "Capsules"
    assert html =~ "Review"
    assert html =~ "Publish"
    assert html =~ "Graph"
    assert html =~ "regents techtree train"
    assert html =~ "regents techtree capsule"
    assert html =~ "regents techtree review"
    assert html =~ "regents techtree publish"
    assert html =~ "regents techtree graph"
    assert html =~ "https://www.postgresql.org"
    assert html =~ "https://hexdocs.pm/ecto/Ecto.html"
    assert html =~ "https://hexdocs.pm/phoenix_live_view/welcome.html"
    assert html =~ "https://elixir-lang.org"
    assert html =~ "Open Techtree site"
    assert html =~ "https://techtree.sh"
    assert html =~ "The Regents CLI is your operator console."
    refute html =~ "Open app"
    refute html =~ "Copy prompt"
    refute html =~ "Why this surface exists"
    assert has_element?(techtree, "#platform-shell-sidebar")
    assert has_element?(techtree, "#platform-shell-header-desktop")
    assert has_element?(techtree, "#platform-techtree-hero")
    assert has_element?(techtree, "#platform-techtree-summary-grid")
    assert has_element?(techtree, "#platform-techtree-cli-rails")
  end

  test "autolaunch route renders", %{conn: conn} do
    {:ok, autolaunch, html} = live(conn, "/autolaunch")

    assert html =~ "Capital formation for agents"
    assert html =~ "Autolaunch"
    assert html =~ "Turn agent edge into runway."
    assert html =~ "Open Autolaunch"
    assert html =~ "View CLI"
    assert html =~ "The launch pipeline"
    assert html =~ "Example board"
    assert html =~ "Built for agents, not tokens."
    assert html =~ "Purpose"
    assert html =~ "Operating rails"
    assert html =~ "Agent Skill"
    assert html =~ "Autolaunch preview"
    assert html =~ "Current source"
    assert html =~ "Example rows"
    assert html =~ "Go to App setup"

    assert html =~ "regents autolaunch launch create"
    assert html =~ "regents autolaunch prelaunch publish"
    assert html =~ "regents autolaunch launch run"
    assert html =~ "https://autolaunch.sh"
    refute html =~ "regents autolaunch plan"
    refute html =~ "regents autolaunch preview publish"
    refute html =~ "regents autolaunch launch --id"
    refute html =~ "regents shader"
    refute html =~ "Copy prompt"
    refute html =~ "Open app"
    refute html =~ "Why this surface exists"
    assert has_element?(autolaunch, "#platform-shell-sidebar")
    assert has_element?(autolaunch, "#platform-shell-header-desktop")
    assert has_element?(autolaunch, "#platform-autolaunch-hero")
    assert has_element?(autolaunch, "#platform-autolaunch-summary-grid")
    assert has_element?(autolaunch, "#platform-autolaunch-cli-rails")
  end

  test "regents cli route renders", %{conn: conn} do
    {:ok, regents_cli, html} = live(conn, "/cli")

    assert html =~ "CLI"
    assert html =~ "Regents CLI"
    assert html =~ "Copy page as markdown"
    assert html =~ "The local tool for working with the Regents platform."
    assert html =~ "@regentslabs/cli"
    assert html =~ "Create the local workspace"
    assert html =~ "Start the guided path"
    assert html =~ "regents techtree start"
    assert html =~ "You run a command"
    assert html =~ "For humans"
    assert html =~ "For agents"
    assert html =~ "regents techtree node create"
    assert html =~ "regents autolaunch launch create"
    refute html =~ "regents techtree apply &lt;flow&gt;"
    refute html =~ "regents autolaunch plan"
    refute html =~ "regents auth siwa"
    refute html =~ "regents shader"
    assert html =~ "Go to App setup"
    assert has_element?(regents_cli, "#platform-regents-cli-hero")
    assert has_element?(regents_cli, "#platform-regents-cli-best-first-command")
    assert has_element?(regents_cli, "#platform-regents-cli-guidance")
  end

  test "token info route renders", %{conn: conn} do
    {:ok, token_info, html} = live(conn, "/token-info")

    assert html =~ "Revenue that stays legible from source to stake."
    assert html =~ "$REGENT is the platform revenue token."
    assert html =~ "It is separate from agent tokens."
    assert html =~ "Market cap"
    assert html =~ "Fully diluted"
    assert html =~ "$REGENT on Base"

    assert html =~ "Why the token exists"
    assert html =~ "Share revenue"
    assert html =~ "Support buybacks"
    assert html =~ "Add early staking emissions"

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
    assert html =~ "20% first-year stream"

    assert html =~ "same $REGENT staking rail"
    assert html =~ "same reward claims"

    assert html =~ "agent token&#39;s trading fees from the Uniswap v4 fee hook"
    assert html =~ "raised USDC in CCA auctions."
    assert html =~ "Stablecoin Revenues"
    assert html =~ "Regents Platform"
    assert html =~ "$REGENT rewards pool"
    assert html =~ "Staking does not guarantee yield."
    assert html =~ "Buybacks happen after the staker share"
    assert html =~ "Stake from Platform or Autolaunch. The underlying action is the same."
    assert html =~ "Staking Console"

    assert html =~ "balance left"
    assert html =~ "buybacks"

    assert html =~
             "Openclaw and Hermes agent hosting, with Stripe LLM billing for margin fees on hosted Regents."

    assert html =~ "Where money enters the Regent system"
    assert html =~ "Token Holders"
    assert html =~ "Largest token balances and lockups"

    assert html =~
             "As of April 1, 2026, most tokens are locked or held by the six addresses below."

    assert html =~ "0x8E84...DF6C"
    assert html =~ "0x46F4...C002"
    assert html =~ "7th through 2,208th: Regent community members."
    assert html =~ "How the full token supply is assigned"
    assert html =~ "20% to Clanker Deployment"
    assert html =~ "40% Regents Labs Multisig"
    assert html =~ "40% Clanker Vault - Locked onchain for 1 year then vesting over 2 years"
    assert html =~ "Clanker token deployment"
    assert html =~ "40% growth emissions"
    assert html =~ "20% staking emissions stream"
    assert html =~ "40% long-term incentives"
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

  defp insert_human!(wallet_address, attrs \\ %{}) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: wallet_address,
      wallet_addresses: [wallet_address],
      xmtp_inbox_id: PlatformPhx.XmtpIdentity.deterministic_inbox_id(wallet_address),
      display_name: "owner@regents.sh",
      avatar: Map.get(attrs, :avatar)
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

    company =
      %Company{}
      |> Company.changeset(%{
        owner_human_id: human.id,
        name: "Owner Control Regent",
        slug: slug,
        claimed_label: slug,
        status: "published",
        public_summary: "A company page for launch-flow testing.",
        hero_statement: "The owner should be able to manage this company from its home page."
      })
      |> Repo.insert!()

    agent =
      %Agent{}
      |> Agent.changeset(%{
        owner_human_id: human.id,
        company_id: company.id,
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
