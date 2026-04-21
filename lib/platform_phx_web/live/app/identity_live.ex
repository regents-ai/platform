defmodule PlatformPhxWeb.App.IdentityLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Dashboard
  alias PlatformPhx.RuntimeConfig
  import PlatformPhxWeb.AppComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, services} = Dashboard.services_payload(socket.assigns.current_human)

    socket =
      socket
      |> assign(:page_title, "Claim name")
      |> assign(:services, services)
      |> assign(:claim_island_config, Jason.encode!(claim_island_config()))
      |> assign(:wallet_ready?, wallet_ready?())
      |> assign(:phase1_label, "")
      |> assign(:phase2_label, "")
      |> assign(:phase1_state, Dashboard.name_claim_state("", nil, nil))
      |> assign(:phase2_state, Dashboard.name_claim_state("", nil, nil))
      |> assign_forms()
      |> refresh_name_claim_states()

    {:ok, socket}
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
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="regents"
      header_eyebrow="App setup"
      header_title="Claim identity"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-identity-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <.identity_stage
          services={@services}
          phase1_form={@phase1_form}
          phase2_form={@phase2_form}
          phase1_state={@phase1_state}
          phase2_state={@phase2_state}
          claim_island_config={@claim_island_config}
          wallet_ready?={@wallet_ready?}
        />
      </div>
    </Layouts.app>
    """
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

  defp claim_island_config do
    %{
      privyAppId: RuntimeConfig.privy_app_id(),
      privyClientId: RuntimeConfig.privy_client_id(),
      privySession: "/api/auth/privy/session",
      basenamesMint: "/api/basenames/mint",
      baseRpcUrl: RuntimeConfig.base_rpc_url()
    }
  end

  defp wallet_ready? do
    RuntimeConfig.privy_app_id() not in [nil, ""] and
      RuntimeConfig.privy_client_id() not in [nil, ""]
  end
end
