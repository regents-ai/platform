defmodule PlatformPhxWeb.Router do
  use PlatformPhxWeb, :router

  @public_rate_limit_rules [
    [
      name: :public_writes,
      method: "POST",
      paths: [
        "/api/bug-report",
        "/api/security-report",
        "/api/basenames/credit",
        "/api/basenames/mint",
        "/api/basenames/use"
      ],
      limit: 12,
      window_ms: :timer.minutes(1)
    ],
    [
      name: :expensive_public_reads,
      method: "GET",
      paths: [
        "/api/basenames/availability",
        "/api/opensea",
        "/api/opensea/redeem-stats"
      ],
      limit: 60,
      window_ms: :timer.minutes(1)
    ]
  ]

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
    plug PlatformPhxWeb.Plugs.RateLimit, rules: @public_rate_limit_rules
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
    plug PlatformPhxWeb.Plugs.RequireAgentSiwa, audience: "regent-services"
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
      live "/", HomeLive
      live "/app", AppEntryLive
      live "/app/access", App.AccessLive
      live "/app/trust", App.TrustLive
      live "/app/identity", App.IdentityLive
      live "/app/billing", App.BillingLive
      live "/app/formation", App.FormationLive
      live "/app/provisioning/:id", App.ProvisioningLive
      live "/app/dashboard", App.DashboardLive
      live "/app/work", App.WorkLive
      live "/app/runs/:id", App.RunLive
      live "/app/runtimes", App.RuntimesLive
      live "/app/agents", App.AgentsLive
      live "/cli", RegentCliLive
      live "/docs", DocsLive
      live "/agents/:slug", AgentSiteLive
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

    get "/regent/staking", Api.RegentStakingController, :show
    get "/regent/staking/account/:address", Api.RegentStakingController, :account
    post "/regent/staking/stake", Api.RegentStakingController, :stake
    post "/regent/staking/unstake", Api.RegentStakingController, :unstake
    post "/regent/staking/claim-usdc", Api.RegentStakingController, :claim_usdc
    post "/regent/staking/claim-regent", Api.RegentStakingController, :claim_regent

    post "/regent/staking/claim-and-restake-regent",
         Api.RegentStakingController,
         :claim_and_restake_regent

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

    get "/rwr/account", RegentWorkRuntimeController, :account
    get "/companies/:company_id/rwr/work-items", RegentWorkRuntimeController, :work_items
    post "/companies/:company_id/rwr/work-items", RegentWorkRuntimeController, :create_work_item

    get "/companies/:company_id/rwr/work-items/:work_item_id",
        RegentWorkRuntimeController,
        :work_item

    post "/companies/:company_id/rwr/work-items/:work_item_id/runs",
         RegentWorkRuntimeController,
         :start_run

    get "/companies/:company_id/rwr/runs/:run_id", RegentWorkRuntimeController, :run
    get "/companies/:company_id/rwr/runs/:run_id/events", RegentWorkRuntimeController, :run_events

    get "/companies/:company_id/rwr/runs/:run_id/artifacts",
        RegentWorkRuntimeController,
        :artifacts

    get "/companies/:company_id/rwr/workers", RegentWorkRuntimeController, :workers
    get "/companies/:company_id/rwr/runtimes", RegentWorkRuntimeController, :runtimes
    post "/companies/:company_id/rwr/runtimes", RegentWorkRuntimeController, :create_runtime
    get "/companies/:company_id/rwr/runtimes/:runtime_id", RegentWorkRuntimeController, :runtime

    post "/companies/:company_id/rwr/runtimes/:runtime_id/checkpoint",
         RegentWorkRuntimeController,
         :checkpoint_runtime

    post "/companies/:company_id/rwr/runtimes/:runtime_id/restore",
         RegentWorkRuntimeController,
         :restore_runtime

    post "/companies/:company_id/rwr/runtimes/:runtime_id/pause",
         RegentWorkRuntimeController,
         :pause_runtime

    post "/companies/:company_id/rwr/runtimes/:runtime_id/resume",
         RegentWorkRuntimeController,
         :resume_runtime

    get "/companies/:company_id/rwr/runtimes/:runtime_id/services",
        RegentWorkRuntimeController,
        :runtime_services

    get "/companies/:company_id/rwr/runtimes/:runtime_id/health",
        RegentWorkRuntimeController,
        :runtime_health

    get "/companies/:company_id/rwr/agents/:source_id/relationships",
        RegentWorkRuntimeController,
        :relationships

    post "/companies/:company_id/rwr/agents/:source_id/relationships",
         RegentWorkRuntimeController,
         :create_relationship

    get "/companies/:company_id/rwr/agents/:manager_id/execution-pool",
        RegentWorkRuntimeController,
        :execution_pool

    delete "/companies/:company_id/rwr/agent-relationships/:relationship_id",
           RegentWorkRuntimeController,
           :delete_relationship
  end

  scope "/api/agent-platform", PlatformPhxWeb.Api do
    pipe_through :shared_agent_api

    post "/ens/prepare-primary", AgentEnsController, :prepare_primary
  end

  scope "/api/agent-platform", PlatformPhxWeb.Api do
    pipe_through :platform_agent_api

    post "/companies/:company_id/rwr/workers", RegentWorkRuntimeController, :register_worker

    post "/companies/:company_id/rwr/workers/:worker_id/heartbeat",
         RegentWorkRuntimeController,
         :heartbeat

    get "/companies/:company_id/rwr/workers/:worker_id/assignments",
        RegentWorkRuntimeController,
        :assignments

    post "/companies/:company_id/rwr/assignments/:assignment_id/claim",
         RegentWorkRuntimeController,
         :claim_assignment

    post "/companies/:company_id/rwr/assignments/:assignment_id/release",
         RegentWorkRuntimeController,
         :release_assignment

    post "/companies/:company_id/rwr/assignments/:assignment_id/complete",
         RegentWorkRuntimeController,
         :complete_assignment

    post "/companies/:company_id/rwr/runs/:run_id/events",
         RegentWorkRuntimeController,
         :append_event

    post "/companies/:company_id/rwr/runs/:run_id/artifacts",
         RegentWorkRuntimeController,
         :create_artifact

    post "/companies/:company_id/rwr/runs/:run_id/delegations",
         RegentWorkRuntimeController,
         :request_delegation
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
