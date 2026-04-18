defmodule PlatformPhxWeb.Router do
  use PlatformPhxWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlatformPhxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug PlatformPhxWeb.BrowserSecurity
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
    pipe_through :browser

    get "/cards/regents-club/:token_id", TokenCardController, :show

    live_session :platform_app,
      session: {PlatformPhxWeb.LiveSessionData, :session, []},
      on_mount: [{PlatformPhxWeb.LiveCurrentHuman, :default}] do
      live "/demo", DemoLive
      live "/heerich-demo", HeerichDemoLive
      live "/", HomeLive
      live "/agents/:slug", AgentSiteLive
      live "/overview", OverviewLive
      live "/logos", LogosLive
      live "/services", DashboardLive, :services
      live "/agent-formation", DashboardLive, :agent_formation
      live "/shader", ShaderLive
      live "/bug-report", BugReportLive
      live "/techtree", TechtreeLive
      live "/autolaunch", AutolaunchLive
      live "/regents-cli", RegentCliLive
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

  scope "/v1/agent/siwa", PlatformPhxWeb.Api do
    pipe_through :api

    post "/nonce", AgentSiwaController, :nonce
    post "/verify", AgentSiwaController, :verify
    post "/http-verify", AgentSiwaController, :http_verify
  end

  scope "/api/auth/privy", PlatformPhxWeb.Api do
    pipe_through :session_api

    get "/csrf", PrivySessionController, :csrf
    post "/session", PrivySessionController, :create
    get "/profile", PrivySessionController, :show
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
    post "/sprites/:slug/pause", AgentFormationController, :pause_sprite
    post "/sprites/:slug/resume", AgentFormationController, :resume_sprite
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
