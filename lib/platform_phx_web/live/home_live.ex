defmodule PlatformPhxWeb.HomeLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.AgentPlatformComponents
  alias PlatformPhxWeb.CompanyRoomComponents
  alias PlatformPhxWeb.CompanyRoomSupport
  @install_command "pnpm add -g @regentslabs/cli"

  @impl true
  def mount(_params, session, socket) do
    host = session["current_host"]
    public_agent = AgentPlatform.get_agent_by_host(host)
    {owner_company, billing_account} = owner_panel(public_agent, socket.assigns.current_human)
    room_agent = room_agent(public_agent, socket.assigns.current_human)

    if connected?(socket) and room_agent do
      :ok = PlatformPhx.Xmtp.subscribe(PlatformPhx.Xmtp.company_room_key(room_agent))
    end

    {:ok,
     socket
     |> assign(:page_title, if(public_agent, do: public_agent.name, else: "Regents Labs"))
     |> assign(:base_app_id, home_base_app_id(host, public_agent))
     |> assign(:install_command, @install_command)
     |> assign(:current_host, host)
     |> assign(
       :public_agent,
       public_agent && AgentPlatform.serialize_agent(public_agent, :public)
     )
     |> assign(:owner_company, owner_company)
     |> assign(:billing_account, billing_account)
     |> assign(
       :xmtp_room,
       CompanyRoomSupport.load_room_panel(room_agent, socket.assigns.current_human)
     )
     |> CompanyRoomSupport.assign_message_form()
     |> assign(:subdomain_missing?, is_nil(public_agent) and subdomain_request?(host))}
  end

  @impl true
  def handle_event("pause_company", %{"slug" => slug}, socket) do
    case Formation.pause_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company paused.")
         |> reload_company_page()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, runtime_error_message(reason))}
    end
  end

  @impl true
  def handle_event("resume_company", %{"slug" => slug}, socket) do
    case Formation.resume_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company running again.")
         |> reload_company_page()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, runtime_error_message(reason))}
    end
  end

  @impl true
  def handle_event("xmtp_join", _params, socket) do
    xmtp_join(socket)
  end

  @impl true
  def handle_event(
        "xmtp_join_signature_signed",
        %{"request_id" => request_id, "signature" => signature},
        socket
      ) do
    xmtp_join_signature_signed(socket, request_id, signature)
  end

  @impl true
  def handle_event("xmtp_join_signature_failed", %{"message" => message}, socket) do
    {:noreply, CompanyRoomSupport.put_status_override(socket, message)}
  end

  @impl true
  def handle_event("xmtp_send", %{"xmtp_room" => %{"body" => body}}, socket) do
    xmtp_send(socket, body)
  end

  @impl true
  def handle_event("xmtp_delete_message", %{"message_id" => message_id}, socket) do
    xmtp_delete_message(socket, message_id)
  end

  @impl true
  def handle_event("xmtp_kick_user", %{"target" => target}, socket) do
    xmtp_kick_user(socket, target)
  end

  @impl true
  def handle_event("xmtp_heartbeat", _params, socket) do
    case room_key(socket) do
      room_key when is_binary(room_key) ->
        :ok = PlatformPhx.Xmtp.heartbeat(socket.assigns.current_human, room_key)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:xmtp_public_room, :refresh}, socket) do
    {:noreply, reload_company_page(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @public_agent do %>
      <Layouts.app
        flash={@flash}
        current_scope={assigns[:current_scope]}
        current_human={assigns[:current_human]}
        chrome={:none}
        show_wallet_control={false}
        theme_class="rg-regent-theme-platform"
        content_class="p-0"
      >
        <div
          id="agent-site-home-shell"
          class="pp-home-shell rg-regent-theme-platform"
          phx-hook="DashboardReveal"
        >
          <div class="p-4 sm:p-6 lg:p-8">
            <AgentPlatformComponents.public_agent_page
              agent={@public_agent}
              owner_company={@owner_company}
              billing_account={@billing_account}
              launch_home_path={launch_home_path(@public_agent)}
            />
            <div class="mt-6">
              <CompanyRoomComponents.company_room
                :if={@xmtp_room}
                room={@xmtp_room}
                form={@xmtp_message_form}
              />
            </div>
          </div>
        </div>
      </Layouts.app>
    <% else %>
      <Layouts.app
        flash={@flash}
        current_scope={assigns[:current_scope]}
        current_human={assigns[:current_human]}
        chrome={:none}
        show_wallet_control={false}
        theme_class="rg-regent-theme-platform"
        content_class="p-0"
      >
        <div
          id="platform-home-shell"
          class="pp-home-shell rg-regent-theme-platform"
          phx-hook="HomeReveal"
        >
          <div class="pp-voxel-background pp-voxel-background--home" aria-hidden="true">
            <div
              id="home-voxel-background"
              class="pp-voxel-background-canvas"
              phx-hook="VoxelBackground"
              data-voxel-background="home"
            >
            </div>
          </div>

          <main id="home-entry" class="pp-home-stage rg-app-shell" aria-label="Regent entry points">
            <%= if @subdomain_missing? do %>
              <section class="pp-route-panel pp-product-panel mx-auto max-w-[760px]">
                <p class="pp-home-kicker">Subdomain not active</p>
                <h1 class="pp-route-panel-title">No published agent lives on this host yet.</h1>
                <p class="pp-panel-copy">
                  Claim a name, finish company setup, and publish the company page before this host goes live.
                </p>
                <div class="pp-link-row">
                  <.link navigate={~p"/app"} class="pp-link-button pp-link-button-slim">
                    Open app <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </section>
            <% else %>
              <div class="mx-auto w-full max-w-[1520px] px-3 py-3 sm:px-5 sm:py-5 lg:px-6 lg:py-6">
                <section class="overflow-hidden rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,var(--foreground)_12%)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_97%,var(--card)_3%),color-mix(in_oklch,var(--background)_93%,var(--card)_7%))] shadow-[0_40px_120px_-70px_color-mix(in_oklch,var(--foreground)_22%,transparent)]">
                  <header class="border-b border-[color:color-mix(in_oklch,var(--border)_92%,transparent)]">
                    <div class="flex flex-col gap-5 px-5 py-4 sm:px-7 lg:flex-row lg:items-center lg:justify-between lg:px-8 lg:py-5">
                      <.link
                        navigate={~p"/"}
                        class="flex items-center gap-3 text-[color:var(--foreground)]"
                      >
                        <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-[color:color-mix(in_oklch,var(--brand-ink)_86%,var(--foreground)_14%)] shadow-[inset_0_1px_0_color-mix(in_oklch,var(--background)_22%,transparent)]">
                          <img
                            src={~p"/images/regents-logo.png"}
                            alt="Regents"
                            class="h-8 w-8 rounded-xl object-cover"
                          />
                        </div>
                        <span class="font-display text-[2rem] leading-none tracking-[-0.03em]">
                          Regents
                        </span>
                      </.link>

                      <nav
                        aria-label="Primary"
                        class="flex flex-wrap items-center gap-x-6 gap-y-2 text-[0.98rem] text-[color:color-mix(in_oklch,var(--foreground)_78%,var(--muted-foreground)_22%)]"
                      >
                        <%= for item <- home_nav_items() do %>
                          <.link
                            navigate={item.href}
                            class="transition duration-200 hover:text-[color:var(--foreground)]"
                          >
                            {item.label}
                          </.link>
                        <% end %>
                      </nav>

                      <.link
                        navigate={~p"/app"}
                        id="home-nav-open-app"
                        class="inline-flex items-center justify-center rounded-[0.95rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_88%,var(--foreground)_12%)] px-5 py-3 text-[0.98rem] text-white/95 shadow-[0_18px_40px_-28px_color-mix(in_oklch,var(--brand-ink)_65%,transparent)] transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_22px_48px_-30px_color-mix(in_oklch,var(--brand-ink)_72%,transparent)]"
                      >
                        {if @current_human, do: "Resume formation", else: "Open app"}
                      </.link>
                    </div>
                  </header>

                  <section class="border-b border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] px-5 py-6 sm:px-7 sm:py-8 lg:px-8 lg:py-9">
                    <div class="relative overflow-hidden rounded-[1.75rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_90%,var(--card)_10%),color-mix(in_oklch,var(--background)_96%,var(--card)_4%))] px-5 py-6 sm:px-6 sm:py-7 lg:px-8 lg:py-8">
                      <div class="pointer-events-none absolute inset-0" aria-hidden="true">
                        <div class="absolute inset-0 bg-[radial-gradient(circle_at_18%_16%,color-mix(in_oklch,var(--brand-ink)_10%,transparent),transparent_38%),radial-gradient(circle_at_82%_22%,color-mix(in_oklch,var(--brand-ink)_9%,transparent),transparent_34%)]">
                        </div>
                        <div class="absolute inset-y-0 right-0 w-[42%] border-l border-[color:color-mix(in_oklch,var(--border)_68%,transparent)] opacity-50">
                        </div>
                        <div class="absolute inset-0 bg-[linear-gradient(to_right,color-mix(in_oklch,var(--border)_46%,transparent)_1px,transparent_1px),linear-gradient(to_bottom,color-mix(in_oklch,var(--border)_38%,transparent)_1px,transparent_1px)] bg-[size:18px_18px] opacity-[0.18]">
                        </div>
                      </div>

                      <div class="relative z-10 grid gap-8 lg:grid-cols-[minmax(0,1.08fr)_minmax(21rem,0.92fr)] lg:items-start">
                        <div class="max-w-[44rem] space-y-6" data-home-header>
                          <div class="space-y-4">
                            <p class="text-[11px] uppercase tracking-[0.3em] text-[color:color-mix(in_oklch,var(--brand-ink)_82%,var(--foreground)_18%)]">
                              Hosted company surface for your agent
                            </p>
                            <h1 class="font-display text-[clamp(3.6rem,8.6vw,6.8rem)] leading-[0.86] tracking-[-0.06em] text-[color:var(--foreground)]">
                              Form your agent company.
                            </h1>
                            <p class="max-w-[40rem] text-[1.1rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_72%,var(--muted-foreground)_28%)]">
                              Open the hosted Regent company here. Improve the agent in Techtree, then use Autolaunch when funding comes next.
                            </p>
                          </div>

                          <div class="max-w-[36rem] rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_94%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] p-1 shadow-[0_22px_40px_-34px_color-mix(in_oklch,var(--foreground)_30%,transparent)]">
                            <div class="flex items-center gap-3 rounded-[0.85rem] px-3 py-3">
                              <span class="text-[1.05rem] text-[color:var(--muted-foreground)]">
                                $
                              </span>
                              <code class="min-w-0 flex-1 overflow-x-auto whitespace-nowrap text-[0.98rem] text-[color:var(--foreground)]">
                                {@install_command}
                              </code>
                              <button
                                id="home-command-copy"
                                type="button"
                                phx-hook="ClipboardCopy"
                                data-copy-text={@install_command}
                                class="inline-flex h-10 w-10 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_74%,var(--card)_26%)] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)] hover:text-[color:var(--brand-ink)]"
                                aria-label="Copy Regents CLI install command"
                                title="Copy Regents CLI install command"
                              >
                                <.icon name="hero-document-duplicate-solid" class="size-5" />
                              </button>
                            </div>
                          </div>

                          <div class="flex flex-wrap gap-3" data-home-actions>
                            <.link
                              navigate={~p"/app"}
                              id="home-primary-cta"
                              class="group inline-flex items-center gap-3 rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_88%,var(--foreground)_12%)] px-5 py-3 text-white/95 shadow-[0_20px_50px_-30px_color-mix(in_oklch,var(--brand-ink)_68%,transparent)] transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_24px_58px_-32px_color-mix(in_oklch,var(--brand-ink)_76%,transparent)]"
                            >
                              <span
                                class="flex h-9 w-9 items-center justify-center rounded-[0.8rem] bg-[color:color-mix(in_oklch,var(--background)_16%,transparent)]"
                                aria-hidden="true"
                              >
                                <img
                                  src={~p"/images/regents-logo.png"}
                                  alt=""
                                  class="h-6 w-6 rounded-md object-cover"
                                />
                              </span>
                              <span class="text-[0.98rem]">
                                {if @current_human, do: "Resume formation", else: "Open app"}
                              </span>
                              <span
                                class="text-[1rem] transition duration-200 group-hover:translate-x-0.5"
                                aria-hidden="true"
                              >
                                →
                              </span>
                            </.link>

                            <.link
                              navigate={~p"/cli"}
                              class="inline-flex items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_94%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] px-5 py-3 text-[0.98rem] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]"
                            >
                              View CLI
                            </.link>
                          </div>
                        </div>

                        <section
                          class="relative rounded-[1.7rem] border border-[color:color-mix(in_oklch,var(--border)_94%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] p-5 shadow-[0_24px_54px_-42px_color-mix(in_oklch,var(--foreground)_24%,transparent)] sm:p-6"
                          data-home-panel
                        >
                          <p class="text-[11px] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--foreground)_58%,var(--muted-foreground)_42%)]">
                            The path
                          </p>

                          <div class="relative mt-5 space-y-5">
                            <div class="absolute bottom-6 left-[4.5rem] top-6 w-px bg-[linear-gradient(180deg,color-mix(in_oklch,var(--border)_52%,transparent),color-mix(in_oklch,var(--border)_78%,transparent),color-mix(in_oklch,var(--border)_52%,transparent))]">
                            </div>

                            <%= for step <- home_path_steps() do %>
                              <div
                                class="relative grid grid-cols-[3.5rem_2.75rem_minmax(0,1fr)] items-start gap-4"
                                data-home-step
                              >
                                <div class="flex h-14 w-14 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--brand-ink)]">
                                  <.icon name={step.icon} class="size-7" />
                                </div>

                                <div class="flex h-10 w-10 items-center justify-center rounded-full border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] font-display text-[1.05rem] text-[color:var(--brand-ink)]">
                                  {step.number}
                                </div>

                                <div class="space-y-2 pt-1">
                                  <h2 class="font-display text-[1.9rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                                    {step.title}
                                  </h2>
                                  <p class="max-w-[17rem] text-[0.98rem] leading-7 text-[color:color-mix(in_oklch,var(--foreground)_68%,var(--muted-foreground)_32%)]">
                                    {step.copy}
                                  </p>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        </section>
                      </div>
                    </div>
                  </section>

                  <section
                    class="border-b border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] px-5 py-5 sm:px-7 sm:py-6 lg:px-8"
                    data-home-section
                  >
                    <p class="text-[11px] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--brand-ink)_82%,var(--foreground)_18%)]">
                      What this page gives you
                    </p>

                    <div class="mt-4 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                      <%= for item <- home_capabilities() do %>
                        <article class="rounded-[1.3rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-4 shadow-[0_18px_36px_-34px_color-mix(in_oklch,var(--foreground)_22%,transparent)]">
                          <div class="flex items-start gap-4">
                            <div class="flex h-14 w-14 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] text-[color:var(--brand-ink)]">
                              <.icon name={item.icon} class="size-7" />
                            </div>
                            <div class="space-y-2">
                              <h2 class="font-display text-[1.55rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                                {item.title}
                              </h2>
                              <p class="text-[0.96rem] leading-7 text-[color:color-mix(in_oklch,var(--foreground)_68%,var(--muted-foreground)_32%)]">
                                {item.copy}
                              </p>
                            </div>
                          </div>
                        </article>
                      <% end %>
                    </div>
                  </section>

                  <section
                    class="border-b border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] px-5 py-5 sm:px-7 sm:py-6 lg:px-8"
                    data-home-section
                  >
                    <p class="text-[11px] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--brand-ink)_82%,var(--foreground)_18%)]">
                      Next surfaces
                    </p>

                    <div class="mt-4 grid gap-4 lg:grid-cols-2">
                      <%= for surface <- home_next_surfaces() do %>
                        <article class="rounded-[1.45rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] px-5 py-5 shadow-[0_24px_44px_-36px_color-mix(in_oklch,var(--foreground)_24%,transparent)]">
                          <div class="flex flex-col gap-5 sm:flex-row sm:items-start">
                            <div class={[
                              "flex h-24 w-24 shrink-0 items-center justify-center rounded-[1.15rem] text-[color:var(--background)] shadow-[inset_0_1px_0_color-mix(in_oklch,var(--background)_24%,transparent)]",
                              surface.icon_background
                            ]}>
                              <.icon name={surface.icon} class="size-12" />
                            </div>

                            <div class="space-y-3">
                              <p class="text-[11px] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--brand-ink)_82%,var(--foreground)_18%)]">
                                {surface.kicker}
                              </p>
                              <h2 class="font-display text-[2.2rem] leading-none tracking-[-0.06em] text-[color:var(--foreground)]">
                                {surface.title}
                              </h2>
                              <p class="max-w-[30rem] text-[0.98rem] leading-7 text-[color:color-mix(in_oklch,var(--foreground)_68%,var(--muted-foreground)_32%)]">
                                {surface.copy}
                              </p>
                              <div class="pt-2">
                                <.link
                                  navigate={surface.href}
                                  class="inline-flex items-center gap-2 text-[1rem] text-[color:var(--brand-ink)] transition duration-200 hover:gap-3"
                                >
                                  Open {surface.title}
                                  <span aria-hidden="true">→</span>
                                </.link>
                              </div>
                            </div>
                          </div>
                        </article>
                      <% end %>
                    </div>
                  </section>

                  <section class="px-5 py-5 sm:px-7 sm:py-6 lg:px-8" data-home-section>
                    <div class="flex flex-col gap-5 rounded-[1.45rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
                      <div class="flex items-start gap-4">
                        <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] text-[color:var(--brand-ink)]">
                          <.icon name="hero-arrow-down-tray-solid" class="size-6" />
                        </div>

                        <div>
                          <p class="text-[11px] uppercase tracking-[0.28em] text-[color:color-mix(in_oklch,var(--brand-ink)_82%,var(--foreground)_18%)]">
                            Operator quickstart
                          </p>
                          <p class="mt-2 max-w-[40rem] text-[0.98rem] leading-7 text-[color:color-mix(in_oklch,var(--foreground)_68%,var(--muted-foreground)_32%)]">
                            Install the CLI for machine work, open the app for guided company setup, or head to the docs when you need the reference surface.
                          </p>
                        </div>
                      </div>

                      <div class="flex flex-wrap gap-3">
                        <.link
                          navigate={~p"/cli"}
                          class="inline-flex items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_80%,var(--card)_20%)] px-5 py-3 text-[0.96rem] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]"
                        >
                          View CLI
                        </.link>
                        <.link
                          navigate={~p"/app"}
                          class="inline-flex items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_80%,var(--card)_20%)] px-5 py-3 text-[0.96rem] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]"
                        >
                          Open app
                        </.link>
                        <.link
                          navigate={~p"/docs"}
                          class="inline-flex items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_92%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_80%,var(--card)_20%)] px-5 py-3 text-[0.96rem] text-[color:var(--foreground)] transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--ring)]"
                        >
                          Open docs
                        </.link>
                      </div>
                    </div>
                  </section>

                  <footer
                    class="border-t border-[color:color-mix(in_oklch,var(--border)_90%,transparent)] px-5 py-5 sm:px-7 lg:px-8"
                    data-home-section
                  >
                    <div class="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
                      <div class="flex flex-col gap-4 text-[0.96rem] text-[color:color-mix(in_oklch,var(--foreground)_62%,var(--muted-foreground)_38%)] sm:flex-row sm:items-center sm:gap-5">
                        <p>&copy; Regents Labs 2026</p>
                        <Layouts.footer_social_links />
                      </div>

                      <div class="text-[0.96rem] text-[color:color-mix(in_oklch,var(--foreground)_62%,var(--muted-foreground)_38%)]">
                        <Layouts.footer_resource_links />
                      </div>
                    </div>
                  </footer>
                </section>
              </div>
            <% end %>
          </main>
        </div>
      </Layouts.app>
    <% end %>
    """
  end

  defp home_nav_items do
    [
      %{label: "Regents", href: "/"},
      %{label: "Techtree", href: "/techtree"},
      %{label: "Autolaunch", href: "/autolaunch"},
      %{label: "CLI", href: "/cli"},
      %{label: "Docs", href: "/docs"}
    ]
  end

  defp home_path_steps do
    [
      %{
        number: "1",
        title: "Form",
        copy: "Claim identity, add billing, and open the company.",
        icon: "hero-building-office-2-solid"
      },
      %{
        number: "2",
        title: "Improve",
        copy: "Use Techtree for research, publishing, and collaboration.",
        icon: "hero-beaker-solid"
      },
      %{
        number: "3",
        title: "Fund",
        copy: "Use Autolaunch when launch planning and capital come next.",
        icon: "hero-rocket-launch-solid"
      }
    ]
  end

  defp home_capabilities do
    [
      %{
        title: "Regent identity",
        copy: "Keep one claimed name tied to the company you are building.",
        icon: "hero-identification-solid"
      },
      %{
        title: "Hosted company",
        copy: "Open the company in one guided flow and come back to control it later.",
        icon: "hero-building-office-2-solid"
      },
      %{
        title: "Local CLI",
        copy: "Install the local tool when the work moves onto a machine or into an agent.",
        icon: "hero-command-line-solid"
      },
      %{
        title: "Next surfaces",
        copy: "Step into Techtree to improve the agent and Autolaunch when funding is next.",
        icon: "hero-rectangle-stack-solid"
      }
    ]
  end

  defp home_next_surfaces do
    [
      %{
        kicker: "Improve the agent",
        title: "Techtree",
        copy: "Open the research, publishing, and collaboration lane after the company is ready.",
        href: "/techtree",
        icon: "hero-beaker-solid",
        icon_background:
          "bg-[linear-gradient(135deg,color-mix(in_oklch,var(--brand-ink)_94%,var(--foreground)_6%),color-mix(in_oklch,var(--brand-ink)_72%,var(--foreground)_28%))]"
      },
      %{
        kicker: "Fund the agent",
        title: "Autolaunch",
        copy:
          "Use the funding lane when launch planning, capital, and post-launch tracking come next.",
        href: "/autolaunch",
        icon: "hero-rocket-launch-solid",
        icon_background: "bg-[linear-gradient(135deg,oklch(0.69_0.16_205),oklch(0.77_0.12_168))]"
      }
    ]
  end

  defp subdomain_request?(host) when is_binary(host) do
    with true <- String.ends_with?(host, ".regents.sh"),
         subdomain when subdomain not in ["", "www"] <- String.trim_trailing(host, ".regents.sh") do
      true
    else
      _ -> false
    end
  end

  defp subdomain_request?(_host), do: false

  defp reload_company_page(socket) do
    public_agent = AgentPlatform.get_agent_by_host(socket.assigns.current_host)
    {owner_company, billing_account} = owner_panel(public_agent, socket.assigns.current_human)
    room_agent = room_agent(public_agent, socket.assigns.current_human)

    socket
    |> assign(:page_title, if(public_agent, do: public_agent.name, else: "Regents Labs"))
    |> assign(:public_agent, public_agent && AgentPlatform.serialize_agent(public_agent, :public))
    |> assign(:owner_company, owner_company)
    |> assign(:billing_account, billing_account)
    |> assign(
      :xmtp_room,
      CompanyRoomSupport.load_room_panel(room_agent, socket.assigns.current_human)
    )
  end

  defp owner_panel(%{owner_human_id: owner_human_id, slug: slug}, %{id: human_id} = current_human)
       when owner_human_id == human_id do
    owned_agent = AgentPlatform.get_owned_agent(current_human, slug)
    owner_company = owned_agent && AgentPlatform.serialize_agent(owned_agent, :private)

    billing_account =
      current_human
      |> AgentPlatform.get_billing_account()
      |> AgentPlatform.billing_account_payload(List.wrap(owned_agent))

    {owner_company, billing_account}
  end

  defp owner_panel(_public_agent, _current_human), do: {nil, nil}

  defp launch_home_path(nil), do: nil
  defp launch_home_path(agent), do: ~p"/app/formation?claimedLabel=#{agent.slug}"

  defp room_agent(%{slug: slug}, %{} = current_human),
    do: AgentPlatform.get_owned_agent(current_human, slug) || AgentPlatform.get_public_agent(slug)

  defp room_agent(%{slug: slug}, _current_human), do: AgentPlatform.get_public_agent(slug)
  defp room_agent(_public_agent, _current_human), do: nil

  defp room_key(socket) do
    socket
    |> room_agent_from_socket()
    |> case do
      nil -> nil
      agent -> PlatformPhx.Xmtp.company_room_key(agent)
    end
  end

  defp room_agent_from_socket(socket),
    do: room_agent(socket.assigns.public_agent, socket.assigns.current_human)

  defp xmtp_join(socket) do
    with room_key when is_binary(room_key) <- room_key(socket),
         response <- PlatformPhx.Xmtp.request_join(socket.assigns.current_human, room_key, %{}) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:needs_signature,
         %{request_id: request_id, signature_text: signature_text, panel: panel}} ->
          {:noreply,
           socket
           |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
           |> push_event("xmtp:sign-request", %{
             request_id: request_id,
             signature_text: signature_text,
             wallet_address: panel.connected_wallet
           })}

        {:error, reason} ->
          {:noreply,
           CompanyRoomSupport.put_status_override(
             socket,
             CompanyRoomSupport.reason_message(reason)
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp xmtp_join_signature_signed(socket, request_id, signature) do
    with room_key when is_binary(room_key) <- room_key(socket),
         response <-
           PlatformPhx.Xmtp.complete_join_signature(
             socket.assigns.current_human,
             request_id,
             signature,
             room_key,
             %{}
           ) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply,
           CompanyRoomSupport.put_status_override(
             socket,
             CompanyRoomSupport.reason_message(reason)
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp xmtp_send(socket, body) do
    with room_key when is_binary(room_key) <- room_key(socket),
         response <- PlatformPhx.Xmtp.send_message(socket.assigns.current_human, body, room_key) do
      case response do
        {:ok, panel} ->
          {:noreply,
           socket
           |> assign(:xmtp_room, Map.put(panel, :status_override, nil))
           |> CompanyRoomSupport.assign_message_form()}

        {:error, reason} ->
          {:noreply,
           socket
           |> CompanyRoomSupport.assign_message_form(body)
           |> CompanyRoomSupport.put_status_override(CompanyRoomSupport.reason_message(reason))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp xmtp_delete_message(socket, message_id) do
    with room_key when is_binary(room_key) <- room_key(socket),
         response <-
           PlatformPhx.Xmtp.moderator_delete_message(
             socket.assigns.current_human,
             message_id,
             room_key
           ) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply,
           CompanyRoomSupport.put_status_override(
             socket,
             CompanyRoomSupport.reason_message(reason)
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp xmtp_kick_user(socket, target) do
    with room_key when is_binary(room_key) <- room_key(socket),
         response <- PlatformPhx.Xmtp.kick_user(socket.assigns.current_human, target, room_key) do
      case response do
        {:ok, panel} ->
          {:noreply, assign(socket, :xmtp_room, Map.put(panel, :status_override, nil))}

        {:error, reason} ->
          {:noreply,
           CompanyRoomSupport.put_status_override(
             socket,
             CompanyRoomSupport.reason_message(reason)
           )}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp runtime_error_message({_, _, message}) when is_binary(message), do: message
  defp runtime_error_message({_, message}) when is_binary(message), do: message
  defp runtime_error_message(message) when is_binary(message), do: message
  defp runtime_error_message(reason), do: inspect(reason)

  defp home_base_app_id(host, nil) when is_binary(host) do
    if PlatformPhxWeb.SiteUrl.public_entry_host?(host) do
      "698e58d4af60e86d051b5246"
    end
  end

  defp home_base_app_id(_host, _public_agent), do: nil
end
