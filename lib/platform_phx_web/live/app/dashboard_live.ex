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
      header_eyebrow="Open app"
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
          <.dashboard_not_ready_stage
            formation={@formation_data}
            notice={@formation_notice}
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

  attr :formation, :map, required: true
  attr :notice, :map, default: nil

  defp dashboard_not_ready_stage(assigns) do
    ~H"""
    <section class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6 shadow-[0_20px_60px_-40px_color-mix(in_oklch,var(--brand-ink)_40%,transparent)]">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="space-y-3">
          <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
            Dashboard
          </p>
          <h2 class="font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
            Open a company to make this your home.
          </h2>
          <p class="max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
            {dashboard_not_ready_copy(@formation)}
          </p>
        </div>

        <.link
          navigate={~p"/app/formation"}
          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
        >
          Open Agent Formation
        </.link>
      </div>

      <%= if @notice do %>
        <.inline_notice notice={@notice} class="mt-6" />
      <% end %>

      <div class="mt-6 space-y-4">
        <div class="max-w-[46rem]">
          <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
            Next steps
          </p>
          <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
            Techtree is where you improve the agent. Autolaunch is where you go when you are ready to raise and grow.
          </p>
        </div>

        <.sister_project_cards />
      </div>
    </section>
    """
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
