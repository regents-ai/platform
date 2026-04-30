defmodule PlatformPhxWeb.AgentSiteLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhxWeb.CompanyRoomComponents
  alias PlatformPhxWeb.PublicCompanyPage

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    agent = AgentPlatform.get_public_agent(slug)
    :ok = PublicCompanyPage.subscribe(socket, agent)

    {:ok,
     socket
     |> assign(:slug, slug)
     |> PublicCompanyPage.assign_company_state(agent, :agent, agent, route_title(agent, slug))
     |> PublicCompanyPage.assign_message_form()}
  end

  @impl true
  def handle_event("pause_company", %{"slug" => slug}, socket) do
    case Formation.pause_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company paused.")
         |> reload_agent_preview()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, PublicCompanyPage.runtime_error_message(reason))}
    end
  end

  @impl true
  def handle_event("resume_company", %{"slug" => slug}, socket) do
    case Formation.resume_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company running again.")
         |> reload_agent_preview()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, PublicCompanyPage.runtime_error_message(reason))}
    end
  end

  @impl true
  def handle_event("xmtp_join", _params, socket) do
    PublicCompanyPage.handle_xmtp_join(socket, socket.assigns.agent)
  end

  @impl true
  def handle_event("xmtp_send", %{"xmtp_room" => %{"body" => body}}, socket) do
    PublicCompanyPage.handle_xmtp_send(socket, socket.assigns.agent, body)
  end

  @impl true
  def handle_event("xmtp_delete_message", %{"message_id" => message_id}, socket) do
    PublicCompanyPage.handle_xmtp_delete_message(socket, socket.assigns.agent, message_id)
  end

  @impl true
  def handle_event("xmtp_kick_user", %{"target" => target}, socket) do
    PublicCompanyPage.handle_xmtp_kick_user(socket, socket.assigns.agent, target)
  end

  @impl true
  def handle_event("xmtp_heartbeat", _params, socket) do
    PublicCompanyPage.handle_xmtp_heartbeat(socket, socket.assigns.agent)
  end

  @impl true
  def handle_info({:public_site_event, %{event: event}}, socket)
      when event in [:xmtp_room_message, :xmtp_room_membership] do
    {:noreply, reload_agent_preview(socket)}
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
      header_eyebrow="Public company"
      header_title={route_title(@agent, @slug)}
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="agent-site-preview-shell"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="pp-route-stage space-y-5">
          <%= if @agent do %>
            <section class="pp-route-grid" data-dashboard-block>
              <article class="pp-route-panel pp-product-panel pp-route-panel-span overflow-hidden px-5 py-5 lg:px-6 lg:py-6">
                <div class="grid gap-7 xl:grid-cols-[minmax(0,1.02fr)_minmax(33rem,0.98fr)]">
                  <div class="space-y-5">
                    <div class="flex items-center gap-2 text-sm text-[color:var(--muted-foreground)]">
                      <.link
                        navigate={~p"/"}
                        class="inline-flex items-center gap-2 hover:text-[color:var(--foreground)]"
                      >
                        <.icon name="hero-arrow-left" class="h-4 w-4" /> Public companies
                      </.link>
                      <span aria-hidden="true">›</span>
                      <span>{@slug}</span>
                    </div>

                    <div class="flex flex-col gap-5 lg:flex-row lg:items-start">
                      <div class="flex h-[7.4rem] w-[7.4rem] shrink-0 items-center justify-center rounded-[1.3rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)]">
                        <img
                          src={~p"/images/regents-logo.png"}
                          alt=""
                          class="h-[4.7rem] w-[4.7rem] rounded-[1rem] object-cover"
                        />
                      </div>

                      <div class="min-w-0 space-y-3">
                        <div class="flex flex-wrap items-center gap-3">
                          <h1 class="font-display text-[clamp(2.4rem,4.8vw,3.8rem)] leading-[0.9] tracking-[-0.06em] text-[color:var(--foreground)]">
                            {display_name(@agent)}
                          </h1>
                          <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-[color:var(--brand-ink)] text-[color:var(--background)]">
                            <.icon name="hero-check-badge" class="h-4 w-4" />
                          </span>
                        </div>

                        <p class="text-[1.28rem] leading-none tracking-[-0.03em] text-[color:var(--foreground)]">
                          Regent company
                        </p>

                        <div class="flex flex-wrap items-center gap-3 text-sm">
                          <span class="inline-flex items-center gap-2 rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-3 py-2 text-[color:var(--foreground)]">
                            <.icon name="hero-globe-alt" class="h-4 w-4" /> Public company home
                          </span>

                          <a
                            :if={public_hostname(@agent)}
                            href={"https://#{public_hostname(@agent)}"}
                            target="_blank"
                            rel="noreferrer"
                            class="inline-flex items-center gap-2 text-[color:var(--brand-ink)] underline decoration-[color:color-mix(in_oklch,var(--brand-ink)_28%,transparent)] underline-offset-4"
                          >
                            {public_hostname(@agent)}
                            <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                          </a>
                        </div>

                        <p class="max-w-[39rem] text-[1.02rem] leading-8 text-[color:var(--muted-foreground)]">
                          {company_description(@agent)}
                        </p>

                        <div
                          :if={public_avatar(@agent)}
                          class={public_avatar_card_class(public_avatar(@agent))}
                        >
                          <p class="pp-home-kicker">Saved avatar</p>
                          <p class="mt-3 font-display text-[1.45rem] text-[color:var(--foreground)]">
                            {AvatarSelection.current_label(public_avatar(@agent))}
                          </p>
                          <p class="mt-2 max-w-[40ch] text-sm leading-6 text-[color:var(--muted-foreground)]">
                            {public_avatar_copy(public_avatar(@agent))}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="grid gap-4 rounded-[1.3rem] border border-[color:var(--border)] bg-[color:var(--card)] px-5 py-5 sm:grid-cols-2 xl:grid-cols-4">
                    <%= for fact <- public_company_fact_cards(@agent) do %>
                      <section class="space-y-4">
                        <span class="inline-flex h-12 w-12 items-center justify-center rounded-[0.95rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                          <.icon name={fact.icon} class="h-5 w-5" />
                        </span>
                        <div class="space-y-2">
                          <p class="text-[0.92rem] leading-6 text-[color:var(--muted-foreground)]">
                            {fact.label}
                          </p>
                          <p class={[
                            "font-display text-[1.9rem] leading-none tracking-[-0.04em]",
                            fact.value_class
                          ]}>
                            {fact.value}
                          </p>
                          <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                            {fact.copy}
                          </p>
                        </div>
                      </section>
                    <% end %>
                  </div>
                </div>
              </article>
            </section>

            <section :if={@owner_company} class="pp-route-grid" data-dashboard-block>
              <article class="pp-route-panel pp-product-panel pp-route-panel-span px-5 py-4">
                <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                  <div class="space-y-2">
                    <p class="pp-home-kicker">Owner controls</p>
                    <p class="text-[0.98rem] leading-7 text-[color:var(--muted-foreground)]">
                      This page is the public home for the company. You can still review billing from here.
                    </p>
                  </div>

                  <div class="flex flex-wrap gap-3">
                    <div class="rounded-[0.95rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-4 py-3 text-sm text-[color:var(--foreground)]">
                      Work balance: {billing_balance(@billing_account)}
                    </div>

                    <button
                      :if={
                        RuntimeConfig.agent_formation_enabled?() and
                          owner_company_paused?(@owner_company)
                      }
                      id="agent-owner-resume"
                      type="button"
                      phx-click="resume_company"
                      phx-value-slug={@owner_company.slug}
                      class="pp-link-button pp-link-button-slim"
                    >
                      Resume company
                    </button>

                    <button
                      :if={
                        RuntimeConfig.agent_formation_enabled?() and
                          !owner_company_paused?(@owner_company)
                      }
                      id="agent-owner-pause"
                      type="button"
                      phx-click="pause_company"
                      phx-value-slug={@owner_company.slug}
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                    >
                      Pause company
                    </button>

                    <button
                      :if={!RuntimeConfig.agent_formation_enabled?()}
                      type="button"
                      disabled
                      title="Coming soon"
                      aria-label={
                        if owner_company_paused?(@owner_company),
                          do: "Resume company, coming soon",
                          else: "Pause company, coming soon"
                      }
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim cursor-not-allowed opacity-65"
                    >
                      <%= if owner_company_paused?(@owner_company) do %>
                        Resume company
                      <% else %>
                        Pause company
                      <% end %>
                    </button>

                    <.link
                      navigate={~p"/app"}
                      class="pp-link-button pp-link-button-slim"
                    >
                      Company controls
                    </.link>
                  </div>
                </div>
              </article>
            </section>

            <section class="pp-route-grid" data-dashboard-block>
              <div class="grid gap-4 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.02fr)_minmax(0,0.88fr)]">
                <article class="pp-route-panel pp-product-panel px-4 py-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        Company profile
                      </h2>
                    </div>
                    <.link
                      :if={@owner_company}
                      navigate={~p"/app"}
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                    >
                      Edit profile
                    </.link>
                  </div>

                  <div class="mt-4 divide-y divide-[color:color-mix(in_oklch,var(--border)_84%,transparent)] rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card)]">
                    <%= for fact <- company_profile_rows(@agent) do %>
                      <div class="grid grid-cols-[1.15rem_5.5rem_minmax(0,1fr)] items-start gap-4 px-4 py-4">
                        <span class="inline-flex h-7 w-7 items-center justify-center rounded-[0.7rem] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]">
                          <.icon name={fact.icon} class="h-3.5 w-3.5" />
                        </span>
                        <p class="text-sm leading-7 text-[color:var(--muted-foreground)]">
                          {fact.label}
                        </p>
                        <p class="text-[0.98rem] leading-7 text-[color:var(--foreground)]">
                          {fact.value}
                        </p>
                      </div>
                    <% end %>
                  </div>

                  <div class="mt-4">
                    <.link
                      navigate={~p"/docs"}
                      class="pp-link-button pp-link-button-slim w-full justify-center"
                    >
                      View full details <span aria-hidden="true">→</span>
                    </.link>
                  </div>
                </article>

                <article class="pp-route-panel pp-product-panel px-4 py-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        Services
                      </h2>
                      <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        What {display_name(@agent)} builds and offers.
                      </p>
                    </div>
                    <a
                      :if={public_hostname(@agent)}
                      href={"https://#{public_hostname(@agent)}"}
                      target="_blank"
                      rel="noreferrer"
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                    >
                      View all services
                    </a>
                  </div>

                  <div class="mt-4 divide-y divide-[color:color-mix(in_oklch,var(--border)_84%,transparent)] rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card)]">
                    <%= for service <- @agent.services || [] do %>
                      <section class="flex items-start gap-4 px-4 py-4">
                        <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-[0.8rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]">
                          <.icon name={service_icon(service)} class="h-4 w-4" />
                        </span>
                        <div class="min-w-0 flex-1">
                          <h3 class="font-display text-[1.04rem] leading-none text-[color:var(--foreground)]">
                            {service.name}
                          </h3>
                          <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                            {service.summary}
                          </p>
                        </div>
                        <span class="text-[color:var(--muted-foreground)]" aria-hidden="true">›</span>
                      </section>
                    <% end %>
                  </div>
                </article>

                <article class="pp-route-panel pp-product-panel px-4 py-4">
                  <div>
                    <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                      Company at a glance
                    </h2>
                  </div>

                  <div class="mt-4 divide-y divide-[color:color-mix(in_oklch,var(--border)_84%,transparent)] rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card)]">
                    <%= for fact <- company_glance_rows(@agent, @xmtp_room) do %>
                      <div class="grid grid-cols-[1.15rem_minmax(0,1fr)_auto] items-start gap-4 px-4 py-4">
                        <span class="inline-flex h-7 w-7 items-center justify-center rounded-[0.7rem] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]">
                          <.icon name={fact.icon} class="h-3.5 w-3.5" />
                        </span>
                        <p class="text-sm leading-7 text-[color:var(--muted-foreground)]">
                          {fact.label}
                        </p>
                        <p class="text-[0.98rem] leading-7 text-[color:var(--foreground)]">
                          {fact.value}
                        </p>
                      </div>
                    <% end %>
                  </div>

                  <div class="mt-4">
                    <.link
                      navigate={~p"/docs"}
                      class="pp-link-button pp-link-button-slim w-full justify-center"
                    >
                      View full details <span aria-hidden="true">→</span>
                    </.link>
                  </div>
                </article>
              </div>
            </section>

            <section class="pp-route-grid" data-dashboard-block>
              <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
                <article class="pp-route-panel pp-product-panel px-4 py-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        Recent finished work
                      </h2>
                      <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Latest completed outputs and updates from the company.
                      </p>
                    </div>
                    <a
                      :if={public_hostname(@agent)}
                      href={"https://#{public_hostname(@agent)}"}
                      target="_blank"
                      rel="noreferrer"
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                    >
                      View all work
                    </a>
                  </div>

                  <div class="mt-4 divide-y divide-[color:color-mix(in_oklch,var(--border)_84%,transparent)] rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card)]">
                    <%= for artifact <- agent_activity_feed(@agent) do %>
                      <section class="grid grid-cols-[2rem_minmax(0,1fr)_auto_auto] items-start gap-4 px-4 py-4">
                        <span class="inline-flex h-10 w-10 items-center justify-center rounded-[0.8rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]">
                          <.icon name="hero-document-text" class="h-4 w-4" />
                        </span>
                        <div class="min-w-0">
                          <h3 class="font-display text-[1.02rem] leading-none text-[color:var(--foreground)]">
                            {artifact.title}
                          </h3>
                          <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                            {artifact.summary}
                          </p>
                        </div>
                        <span
                          class="rounded-full px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--brand-ink)]"
                          style={"background-color: #{artifact_badge_background(artifact)}"}
                        >
                          {artifact_badge(artifact)}
                        </span>
                        <span class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                          {artifact_time_label(artifact)}
                        </span>
                      </section>
                    <% end %>
                  </div>

                  <div class="mt-4">
                    <.link
                      navigate={~p"/docs"}
                      class="pp-link-button pp-link-button-slim w-full justify-center"
                    >
                      View all finished work <span aria-hidden="true">→</span>
                    </.link>
                  </div>
                </article>

                <article :if={@xmtp_room} class="pp-route-panel pp-product-panel px-4 py-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                        Talk with this company in one shared room
                      </h2>
                      <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        Join the public room to ask questions, share context, and stay updated.
                      </p>
                    </div>

                    <.link
                      navigate={~p"/app"}
                      class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                    >
                      Company controls
                    </.link>
                  </div>

                  <div class="mt-4">
                    <CompanyRoomComponents.company_room room={@xmtp_room} form={@xmtp_message_form} />
                  </div>
                </article>
              </div>
            </section>
          <% else %>
            <section class="pp-route-grid" data-dashboard-block>
              <article class="pp-route-panel pp-product-panel pp-product-panel--feature px-5 py-6">
                <p class="pp-home-kicker">Public company</p>
                <h1 class="font-display text-[clamp(2.4rem,5vw,4.2rem)] leading-[0.9] tracking-[-0.05em] text-[color:var(--foreground)]">
                  Agent not found
                </h1>
                <p class="mt-4 max-w-[34rem] text-[1rem] leading-7 text-[color:var(--muted-foreground)]">
                  No published company matches <code>{@slug}</code>.
                </p>
                <div class="mt-6 flex flex-wrap gap-3">
                  <.link navigate={~p"/"} class="pp-link-button pp-link-button-slim">
                    Back to Regents <span aria-hidden="true">→</span>
                  </.link>
                  <.link
                    navigate={~p"/docs"}
                    class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                  >
                    Open Docs <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </article>
            </section>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp reload_agent_preview(socket) do
    agent = AgentPlatform.get_public_agent(socket.assigns.slug)

    socket
    |> PublicCompanyPage.assign_company_state(
      agent,
      :agent,
      agent,
      route_title(agent, socket.assigns.slug)
    )
  end

  defp owner_company_paused?(company) do
    company.desired_runtime_state == "paused" or company.runtime_status == "paused"
  end

  defp billing_balance(%{runtime_credit_balance_usd_cents: cents}) when is_integer(cents) do
    "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp billing_balance(_billing_account), do: "$0.00"

  defp route_title(%{name: name}, _slug) when is_binary(name) and name != "", do: name
  defp route_title(_agent, slug), do: "Public company #{slug}"

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{slug: slug}), do: slug
  defp display_name(_agent), do: "Public company"

  defp route_summary(%{hero_statement: statement}) when is_binary(statement) and statement != "",
    do: statement

  defp route_summary(%{public_summary: summary}) when is_binary(summary) and summary != "",
    do: summary

  defp route_summary(_agent) do
    "See what this company offers, what it has shipped, and how to reach it."
  end

  defp company_description(%{hero_statement: statement})
       when is_binary(statement) and statement != "",
       do: statement

  defp company_description(agent), do: route_summary(agent)

  defp public_hostname(%{subdomain: %{active: true, hostname: hostname}})
       when is_binary(hostname) and hostname != "",
       do: hostname

  defp public_hostname(_agent), do: nil

  defp public_company_fact_cards(agent) do
    [
      %{
        icon: "hero-building-office-2",
        label: "Company status",
        value: "Active",
        value_class: "text-[color:#159957]",
        copy: "Operating on Regents"
      },
      %{
        icon: "hero-calendar-days",
        label: "Formed",
        value: formed_label(agent),
        value_class: "text-[color:var(--foreground)]",
        copy: "Active since formation"
      },
      %{
        icon: "hero-folder",
        label: "Company type",
        value: "Regent company",
        value_class: "text-[color:var(--foreground)]",
        copy: "Public company"
      },
      %{
        icon: "hero-shield-check",
        label: "Visibility",
        value: "Public",
        value_class: "text-[color:var(--foreground)]",
        copy: "Open to all"
      }
    ]
  end

  defp formed_label(%{published_at: published_at})
       when is_binary(published_at) and published_at != "",
       do: human_date(published_at)

  defp formed_label(_agent), do: "Preparing"

  defp company_profile_rows(agent) do
    [
      %{icon: "hero-sparkles", label: "Claimed name", value: display_name(agent)},
      %{icon: "hero-link", label: "Slug", value: agent.slug},
      %{
        icon: "hero-hashtag",
        label: "Company ID",
        value: "c-#{String.slice(Integer.to_string(agent.id || 0, 36), 0, 7)}"
      },
      %{icon: "hero-calendar-days", label: "Formed", value: formed_label(agent)},
      %{icon: "hero-user-group", label: "Operator", value: owner_label(agent)},
      %{icon: "hero-document-text", label: "Description", value: company_description(agent)}
    ]
  end

  defp company_glance_rows(agent, xmtp_room) do
    [
      %{
        icon: "hero-cube",
        label: "Products",
        value: "#{length(List.wrap(agent.services))} active"
      },
      %{
        icon: "hero-check-badge",
        label: "Finished work",
        value: Integer.to_string(length(agent_activity_feed(agent)))
      },
      %{icon: "hero-user", label: "Team", value: "1 operator"},
      %{
        icon: "hero-chat-bubble-left-right",
        label: "Room",
        value: if(xmtp_room, do: "Public", else: "Private")
      },
      %{icon: "hero-clock", label: "Last update", value: last_update_label(agent)}
    ]
  end

  defp service_icon(service) do
    name = String.downcase(service.name || "")

    cond do
      String.contains?(name, "research") -> "hero-beaker"
      String.contains?(name, "ops") -> "hero-command-line"
      String.contains?(name, "comm") -> "hero-chat-bubble-left-right"
      String.contains?(name, "data") -> "hero-circle-stack"
      true -> "hero-sparkles"
    end
  end

  defp artifact_badge(artifact) do
    haystack = String.downcase("#{artifact.title} #{artifact.summary}")

    cond do
      String.contains?(haystack, "research") -> "Research"
      String.contains?(haystack, "ops") or String.contains?(haystack, "incident") -> "Operations"
      String.contains?(haystack, "data") -> "Data"
      true -> "Product"
    end
  end

  defp artifact_badge_background(artifact) do
    case artifact_badge(artifact) do
      "Research" -> "color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)"
      "Operations" -> "color-mix(in_oklch,#159957_10%,var(--background)_90%)"
      "Data" -> "color-mix(in_oklch,var(--muted-foreground)_10%,var(--background)_90%)"
      _ -> "color-mix(in_oklch,var(--accent)_16%,var(--background)_84%)"
    end
  end

  defp artifact_time_label(%{published_at: published_at})
       when is_binary(published_at) and published_at != "" do
    human_relative_time(published_at)
  end

  defp artifact_time_label(_artifact), do: "Just now"

  defp last_update_label(agent) do
    case agent_activity_feed(agent) do
      [latest | _] -> artifact_time_label(latest)
      _ -> "Just now"
    end
  end

  defp agent_activity_feed(%{feed: feed}) when is_list(feed), do: feed
  defp agent_activity_feed(%{artifacts: artifacts}) when is_list(artifacts), do: artifacts
  defp agent_activity_feed(_agent), do: []

  defp owner_label(%{owner_human_id: owner_human_id}) when is_integer(owner_human_id),
    do: "Platform operator"

  defp owner_label(_agent), do: "Platform operator"

  defp public_avatar_card_class(avatar) do
    [
      "rounded-[1.35rem] border px-4 py-4",
      if(AvatarSelection.gold_border?(avatar),
        do:
          "border-[color:color-mix(in_oklch,#d4a756_72%,var(--border)_28%)] bg-[linear-gradient(180deg,color-mix(in_oklch,#d4a756_14%,transparent),color-mix(in_oklch,var(--card)_94%,transparent))]",
        else:
          "border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_8%,transparent),color-mix(in_oklch,var(--card)_94%,transparent))]"
      )
    ]
  end

  defp public_avatar_copy(%{"kind" => "custom_shader", "shader_id" => shader_id}) do
    AvatarSelection.shader_description(shader_id)
  end

  defp public_avatar_copy(%{
         "kind" => "collection_token",
         "collection" => collection,
         "token_id" => token_id
       }) do
    "#{AvatarSelection.collection_label(collection)} ##{token_id} is the public avatar saved for this company."
  end

  defp public_avatar_copy(_avatar), do: "This saved look appears on the public company page."

  defp public_avatar(%{avatar: avatar}) when is_map(avatar), do: avatar
  defp public_avatar(%{owner_human: %{avatar: avatar}}) when is_map(avatar), do: avatar
  defp public_avatar(_agent), do: nil

  defp human_date(iso8601) do
    with {:ok, datetime, _offset} <- DateTime.from_iso8601(iso8601) do
      Calendar.strftime(datetime, "%b %-d, %Y")
    else
      _ -> iso8601
    end
  end

  defp human_relative_time(iso8601) do
    with {:ok, datetime, _offset} <- DateTime.from_iso8601(iso8601) do
      diff_seconds = max(DateTime.diff(PlatformPhx.Clock.utc_now(), datetime, :second), 0)

      cond do
        diff_seconds < 3600 -> "#{max(div(diff_seconds, 60), 1)}m ago"
        diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
        diff_seconds < 604_800 -> "#{div(diff_seconds, 86_400)}d ago"
        true -> human_date(iso8601)
      end
    else
      _ -> "Just now"
    end
  end
end
