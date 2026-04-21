defmodule PlatformPhxWeb.App.AccessLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Dashboard
  alias PlatformPhx.RuntimeConfig
  import PlatformPhxWeb.AppComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, services} = Dashboard.services_payload(socket.assigns.current_human)

    {:ok,
     socket
     |> assign(:page_title, "Check access")
     |> assign(:services, services)
     |> assign(:redeem_island_config, Jason.encode!(redeem_island_config()))
     |> assign(:wallet_ready?, wallet_ready?())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="regents"
      header_eyebrow="App setup"
      header_title="Check access"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-access-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <.access_stage services={@services} redeem_island_config={@redeem_island_config} />
      </div>
    </Layouts.app>
    """
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
end
