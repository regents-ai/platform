defmodule PlatformPhxWeb.Router do
  use PlatformPhxWeb, :router

  pipeline :browser do
    plug PlatformPhxWeb.PublicEntryPlug
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlatformPhxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug PlatformPhxWeb.BrowserSecurity
  end

  pipeline :public_discovery do
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :session_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PlatformPhxWeb.RequireSessionCsrf
  end

  pipeline :platform_agent_api do
    plug :accepts, ["json"]
    plug PlatformPhxWeb.Plugs.RequireAgentSiwa, audience: "platform"
  end

  pipeline :shared_agent_api do
    plug :accepts, ["json"]
    plug PlatformPhxWeb.Plugs.RequireAgentSiwa, audience: "regents.sh"
  end

  scope "/", PlatformPhxWeb do
    pipe_through :public_discovery

    get "/robots.txt", DiscoveryController, :robots
    get "/sitemap.xml", DiscoveryController, :sitemap
    get "/.well-known/api-catalog", DiscoveryController, :api_catalog
    get "/.well-known/agent-card.json", DiscoveryController, :agent_card
    get "/.well-known/agent-skills/index.json", DiscoveryController, :agent_skills_index
    get "/.well-known/mcp/server-card.json", DiscoveryController, :mcp_server_card
    get "/healthz", DiscoveryController, :healthz
    get "/readyz", DiscoveryController, :readyz
    get "/api-contract.openapiv3.yaml", DiscoveryController, :api_contract
    get "/cli-contract.yaml", DiscoveryController, :cli_contract
    get "/agent-skills/regents-cli.md", DiscoveryController, :regents_cli_skill
  end

  scope "/", PlatformPhxWeb do
    pipe_through :browser

    get "/cards/regents-club/:token_id", TokenCardController, :show

    live_session :platform_app,
      session: {PlatformPhxWeb.LiveSessionData, :session, []},
      on_mount: [
        {PlatformPhxWeb.LiveCurrentHuman, :default},
        {PlatformPhxWeb.LivePageMetadata, :default}
      ] do
      live "/demo", DemoLive
      live "/heerich-demo", HeerichDemoLive
      live "/", HomeLive
      live "/app", AppEntryLive
      live "/app/access", App.AccessLive
      live "/app/trust", App.TrustLive
      live "/app/identity", App.IdentityLive
      live "/app/billing", App.BillingLive
      live "/app/formation", App.FormationLive
      live "/app/provisioning/:id", App.ProvisioningLive
      live "/app/dashboard", App.DashboardLive
      live "/cli", RegentCliLive
      live "/docs", DocsLive
      live "/agents/:slug", AgentSiteLive
      live "/logos", LogosLive
      live "/shader", ShaderLive
      live "/bug-report", BugReportLive
      live "/techtree", TechtreeLive
      live "/autolaunch", AutolaunchLive
      live "/token-info", TokenInfoLive
    end
  end

  scope "/", PlatformPhxWeb do
    pipe_through :api

    get "/metadata/:token_id", MetadataController, :show
  end

  scope "/api", PlatformPhxWeb do
    pipe_through :api

    get "/basenames/config", Api.BasenamesController, :config
    get "/basenames/allowances", Api.BasenamesController, :allowances
    get "/basenames/allowance", Api.BasenamesController, :allowance
    get "/basenames/availability", Api.BasenamesController, :availability
    get "/basenames/credits", Api.BasenamesController, :credits
    get "/basenames/owned", Api.BasenamesController, :owned
    get "/basenames/recent", Api.BasenamesController, :recent
    post "/basenames/credit", Api.BasenamesController, :credit
    post "/basenames/mint", Api.BasenamesController, :mint
    post "/basenames/use", Api.BasenamesController, :use
    post "/bug-report", Api.ReportController, :bug
    post "/security-report", Api.ReportController, :security

    get "/agentlaunch/auctions", Api.AgentLaunchController, :auctions
    get "/opensea", Api.OpenseaController, :index
    get "/opensea/redeem-stats", Api.OpenseaController, :redeem_stats
    get "/agent-platform/templates", Api.AgentPlatformController, :templates
    get "/agent-platform/resolve", Api.AgentPlatformController, :resolve
    get "/agent-platform/agents/:slug/feed", Api.AgentPlatformController, :feed
    get "/regent/staking", Api.RegentStakingController, :show
    get "/regent/staking/account/:address", Api.RegentStakingController, :account
    post "/agent-platform/stripe/webhooks", Api.StripeWebhookController, :create
  end

  scope "/api/auth/privy", PlatformPhxWeb.Api do
    pipe_through :session_api

    get "/csrf", PrivySessionController, :csrf
    post "/session", PrivySessionController, :create
    get "/profile", PrivySessionController, :show
    put "/profile/avatar", PrivySessionController, :update_avatar
    delete "/session", PrivySessionController, :delete
  end

  scope "/api/auth/agent", PlatformPhxWeb.Api do
    pipe_through :session_api

    get "/session", AgentSessionController, :show
    delete "/session", AgentSessionController, :delete
  end

  scope "/api/auth/agent", PlatformPhxWeb.Api do
    pipe_through [:session_api, :platform_agent_api]

    post "/session", AgentSessionController, :create
  end

  scope "/api/agentbook", PlatformPhxWeb.Api do
    pipe_through :session_api

    post "/sessions/:id/submit", AgentbookController, :submit
  end

  scope "/api/agentbook", PlatformPhxWeb.Api do
    pipe_through :shared_agent_api

    post "/sessions", AgentbookController, :create
    get "/sessions/:id", AgentbookController, :show
    get "/lookup", AgentbookController, :lookup
  end

  scope "/v1/agent", PlatformPhxWeb do
    pipe_through :shared_agent_api

    post "/bug-report", Api.ReportController, :agent_bug
    post "/security-report", Api.ReportController, :agent_security
  end

  scope "/api/agent-platform", PlatformPhxWeb.Api do
    pipe_through :session_api

    get "/formation", AgentFormationController, :formation
    post "/billing/setup/checkout", AgentFormationController, :billing_setup_checkout
    get "/billing/account", AgentFormationController, :billing_account
    get "/billing/usage", AgentFormationController, :billing_usage
    post "/billing/topups/checkout", AgentFormationController, :billing_topup_checkout
    post "/formation/companies", AgentFormationController, :create_company
    get "/agents/:slug/runtime", AgentFormationController, :runtime
    post "/ens/claims/:claim_id/prepare-upgrade", AgentEnsController, :prepare_upgrade
    post "/ens/claims/:claim_id/confirm-upgrade", AgentEnsController, :confirm_upgrade
    post "/agents/:slug/ens/attach", AgentEnsController, :attach
    post "/agents/:slug/ens/detach", AgentEnsController, :detach
    post "/agents/:slug/ens/link/plan", AgentEnsController, :link_plan

    post "/agents/:slug/ens/link/prepare-bidirectional",
         AgentEnsController,
         :prepare_bidirectional

    post "/sprites/:slug/pause", AgentFormationController, :pause_sprite
    post "/sprites/:slug/resume", AgentFormationController, :resume_sprite
  end

  scope "/api/agent-platform", PlatformPhxWeb.Api do
    pipe_through :shared_agent_api

    post "/ens/prepare-primary", AgentEnsController, :prepare_primary
  end

  scope "/api/regent/staking", PlatformPhxWeb.Api do
    pipe_through :session_api

    post "/stake", RegentStakingController, :stake
    post "/unstake", RegentStakingController, :unstake
    post "/claim-usdc", RegentStakingController, :claim_usdc
    post "/claim-regent", RegentStakingController, :claim_regent
    post "/claim-and-restake-regent", RegentStakingController, :claim_and_restake_regent
    post "/deposit-usdc/prepare", RegentStakingController, :prepare_deposit
    post "/withdraw-treasury/prepare", RegentStakingController, :prepare_withdraw_treasury
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:platform_phx, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PlatformPhxWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
