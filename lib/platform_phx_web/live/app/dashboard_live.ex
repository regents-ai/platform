defmodule PlatformPhxWeb.App.DashboardLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Accounts
  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.Dashboard
  alias PlatformPhx.RuntimeConfig
  import PlatformPhxWeb.AppComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:formation_data, nil)
     |> assign(:formation_notice, nil)
     |> assign(:dashboard_notices, [])
     |> assign(:avatar_save_notice, nil)
     |> assign(:holdings, empty_holdings())
     |> assign(:formation_token_cards, %{})
     |> assign(:shader_options, AvatarSelection.shader_options())
     |> assign(:usage, %{})
     |> load_payload()}
  end

  @impl true
  def handle_event("pause_company", %{"slug" => slug}, socket) do
    case Formation.pause_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply, socket |> put_flash(:info, "Company paused.") |> load_payload()}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("resume_company", %{"slug" => slug}, socket) do
    case Formation.resume_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply, socket |> put_flash(:info, "Company running again.") |> load_payload()}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("save_avatar", params, socket) do
    case AgentPlatform.save_human_avatar(socket.assigns.current_human, params) do
      {:ok, updated_human} ->
        {:noreply,
         socket
         |> assign(:current_human, Accounts.get_human(updated_human.id))
         |> assign(:avatar_save_notice, %{tone: :success, message: "Saved avatar updated."})
         |> load_payload()}

      {:error, {_status, message}} ->
        {:noreply, assign(socket, :avatar_save_notice, %{tone: :error, message: message})}
    end
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
      header_eyebrow="App"
      header_title="Company dashboard"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-dashboard-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <%= if dashboard_ready?(@formation_data) do %>
          <.dashboard_stage
            formation={@formation_data}
            usage={@usage}
            current_human={@current_human}
            holdings={@holdings}
            formation_token_cards={@formation_token_cards}
            shader_options={@shader_options}
            avatar_save_notice={@avatar_save_notice}
            notice={@formation_notice}
            notices={@dashboard_notices}
          />
        <% else %>
          <.setup_blocked_stage
            step={4}
            title="Open a company to make this your home."
            summary="The dashboard becomes available after a company has been opened."
            snapshot={setup_snapshot_from_formation(@formation_data)}
            facts={[
              %{
                icon: "hero-building-office-2",
                title: "Company live",
                copy: "The dashboard appears after the hosted company is opened."
              },
              %{
                icon: "hero-credit-card",
                title: "Billing visible",
                copy: "Credit and spend show up after launch."
              },
              %{
                icon: "hero-paint-brush",
                title: "Public look",
                copy: "Saved avatar choices appear here after launch."
              }
            ]}
            next_steps={[
              %{
                number: "Docs",
                title: "Use Docs",
                copy: "Review the reference surface while the company is still being set up."
              },
              %{
                number: "CLI",
                title: "Use Regents CLI",
                copy: "Move into the CLI when work starts on a machine or inside an agent."
              }
            ]}
            blocker_copy={dashboard_not_ready_copy(@formation_data)}
            action_label={dashboard_action_label()}
            action_path={dashboard_action_path()}
            action_copy={dashboard_action_copy()}
            notice={@formation_notice}
            readiness={Map.get(@formation_data || %{}, :readiness)}
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket) do
    {:ok, snapshot} = Dashboard.company_snapshot(socket.assigns.current_human)

    socket
    |> assign(:formation_data, snapshot.formation)
    |> assign(:formation_notice, snapshot.notice)
    |> assign(:dashboard_notices, snapshot.notices)
    |> assign(:holdings, snapshot.holdings)
    |> assign(:formation_token_cards, snapshot.formation_token_cards)
    |> assign(:usage, snapshot.usage)
  end

  defp dashboard_ready?(%{owned_companies: owned_companies}) when is_list(owned_companies),
    do: owned_companies != []

  defp dashboard_ready?(_formation), do: false

  defp dashboard_not_ready_copy(%{readiness: %{ready: true}}) do
    if RuntimeConfig.agent_formation_enabled?() do
      "Everything is ready. Open the company, then come back here to manage it."
    else
      "Company opening is paused right now. $REGENT staking is live on the token page."
    end
  end

  defp dashboard_not_ready_copy(%{readiness: %{blocked_step: %{message: message}}})
       when is_binary(message) do
    message
  end

  defp dashboard_not_ready_copy(%{authenticated: true}) do
    "Finish the next setup step, then come back here to manage the company."
  end

  defp dashboard_not_ready_copy(%{authenticated: false}) do
    if RuntimeConfig.agent_formation_enabled?() do
      "Sign in, claim a name, add billing, and open a company. This page becomes your company home after launch."
    else
      "$REGENT staking is live now. Company opening will return when the launch service is ready."
    end
  end

  defp dashboard_not_ready_copy(_formation) do
    if RuntimeConfig.agent_formation_enabled?() do
      "We could not load your company details right now. Open company setup to keep going."
    else
      "$REGENT staking is live now. Company opening will return when the launch service is ready."
    end
  end

  defp dashboard_action_label do
    if RuntimeConfig.agent_formation_enabled?(),
      do: "Open company setup",
      else: "Open $REGENT staking"
  end

  defp dashboard_action_path do
    if RuntimeConfig.agent_formation_enabled?(), do: ~p"/app/formation", else: ~p"/token-info"
  end

  defp dashboard_action_copy do
    if RuntimeConfig.agent_formation_enabled?() do
      "Finish company setup first, then come back here to manage the live company."
    else
      "Use the live token and staking page while company opening is prepared."
    end
  end

  defp empty_holdings do
    %{
      "animata1" => [],
      "animata2" => [],
      "animataPass" => []
    }
  end
end
