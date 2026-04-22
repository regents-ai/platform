defmodule PlatformPhxWeb.App.DashboardLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Accounts
  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.Dashboard
  alias PlatformPhx.TokenCardManifest
  import PlatformPhxWeb.AppComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:formation_data, nil)
     |> assign(:formation_notice, nil)
     |> assign(:avatar_save_notice, nil)
     |> assign(:holdings, empty_holdings())
     |> assign(:formation_token_cards, %{})
     |> assign(:shader_options, AvatarSelection.shader_options())
     |> assign(:usage, empty_usage())
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
            action_label="Open Agent Formation"
            action_path={~p"/app/formation"}
            action_copy="Finish company setup first, then come back here to manage the live company."
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket) do
    usage = load_usage(socket.assigns.current_human)
    holdings = load_holdings(socket.assigns.current_human)

    result =
      case Dashboard.agent_formation_payload(socket.assigns.current_human) do
        {:ok, payload} ->
          payload

        _ ->
          %{
            formation: nil,
            notice: %{tone: :error, message: "Dashboard details are unavailable right now."}
          }
      end

    socket
    |> assign(:formation_data, result.formation)
    |> assign(:formation_notice, result.notice)
    |> assign(:holdings, holdings)
    |> assign(:formation_token_cards, formation_token_cards(holdings))
    |> assign(:usage, usage)
  end

  defp load_usage(nil), do: empty_usage()

  defp load_usage(current_human) do
    case Formation.billing_usage(current_human) do
      {:ok, %{usage: usage}} -> usage
      {:error, _reason} -> empty_usage()
    end
  end

  defp load_holdings(nil), do: empty_holdings()

  defp load_holdings(current_human) do
    case AgentPlatform.holdings_for_human(current_human) do
      {:ok, holdings} -> holdings
      {:error, _reason} -> empty_holdings()
    end
  end

  defp dashboard_ready?(%{owned_companies: owned_companies}) when is_list(owned_companies),
    do: owned_companies != []

  defp dashboard_ready?(_formation), do: false

  defp dashboard_not_ready_copy(%{authenticated: true}) do
    "You are signed in, but no company is open yet. Finish launch in Agent Formation, then come back here to manage it."
  end

  defp dashboard_not_ready_copy(%{authenticated: false}) do
    "Sign in, claim a name, add billing, and launch a company in Agent Formation. This page will become your company home after launch."
  end

  defp dashboard_not_ready_copy(_formation) do
    "We could not load your company details right now. Open Agent Formation to keep going."
  end

  defp empty_usage do
    %{
      runtime_credit_balance_usd_cents: 0,
      runtime_spend_usd_cents: 0,
      llm_spend_usd_cents: 0,
      paid_companies: 0,
      paused_companies: 0,
      trialing_companies: 0,
      welcome_credit: nil,
      companies: []
    }
  end

  defp empty_holdings do
    %{
      "animata1" => [],
      "animata2" => [],
      "animataPass" => []
    }
  end

  defp formation_token_cards(%{"animataPass" => token_ids}) when is_list(token_ids) do
    case TokenCardManifest.fetch_many(token_ids) do
      {:ok, entries} ->
        entries
        |> Enum.reject(fn {_token_id, entry} -> is_nil(entry) end)
        |> Map.new()

      {:error, _reason} ->
        %{}
    end
  end

  defp formation_token_cards(_holdings), do: %{}
end
