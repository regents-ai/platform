defmodule PlatformPhxWeb.HomeLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.AgentPlatformComponents
  import PlatformPhxWeb.AppComponents
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
              <div class="mx-auto flex w-full max-w-[1320px] flex-col gap-10 px-4 py-4 sm:px-6 lg:px-8">
                <header class="flex flex-wrap items-center justify-between gap-4">
                  <.link
                    navigate={~p"/"}
                    class="flex items-center gap-3 text-[color:var(--foreground)]"
                  >
                    <div class="flex h-12 w-12 items-center justify-center rounded-2xl border border-[color:var(--border)] bg-[color:var(--card)]">
                      <img
                        src={~p"/images/regents-logo.png"}
                        alt="Regents"
                        class="h-9 w-9 rounded-xl object-cover"
                      />
                    </div>
                    <span class="font-display text-[1.8rem] leading-none">Regents</span>
                  </.link>

                  <div class="flex flex-wrap items-center gap-3 text-sm text-[color:var(--foreground)]">
                    <.link
                      navigate={~p"/"}
                      class="rounded-full border border-[color:var(--border)] px-4 py-2"
                    >
                      Regents
                    </.link>
                    <.link
                      navigate={~p"/techtree"}
                      class="rounded-full border border-[color:var(--border)] px-4 py-2"
                    >
                      Techtree
                    </.link>
                    <.link
                      navigate={~p"/autolaunch"}
                      class="rounded-full border border-[color:var(--border)] px-4 py-2"
                    >
                      Autolaunch
                    </.link>
                    <.link
                      navigate={~p"/cli"}
                      class="rounded-full border border-[color:var(--border)] px-4 py-2"
                    >
                      CLI
                    </.link>
                    <.link
                      navigate={~p"/docs"}
                      class="rounded-full border border-[color:var(--border)] px-4 py-2"
                    >
                      Docs
                    </.link>
                    <.link
                      navigate={~p"/app"}
                      id="home-nav-open-app"
                      class="pp-home-nav-cta"
                    >
                      {if @current_human, do: "Resume formation", else: "Open app"}
                    </.link>
                  </div>
                </header>

                <main class="space-y-10">
                  <section
                    class="relative overflow-hidden rounded-[2rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--card)_94%,var(--background)_6%),color-mix(in_oklch,var(--background)_88%,var(--card)_12%))] p-6 shadow-[0_28px_90px_-60px_color-mix(in_oklch,var(--brand-ink)_45%,transparent)] sm:p-8 lg:p-10"
                    data-home-hero
                  >
                    <div class="absolute inset-0 opacity-70" aria-hidden="true">
                      <div
                        id="home-voxel-background-canvas"
                        class="h-full w-full"
                        phx-hook="VoxelBackground"
                        data-voxel-background="home"
                      >
                      </div>
                    </div>

                    <div class="relative z-10 grid gap-8 lg:grid-cols-[minmax(0,1.05fr)_minmax(18rem,0.95fr)] lg:items-end">
                      <div class="space-y-6" data-home-header>
                        <p class="text-[10px] uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                          Hosted company surface for your agent
                        </p>
                        <h1 class="font-display text-[clamp(3.2rem,9vw,6.4rem)] leading-[0.88] text-[color:var(--foreground)]">
                          Form your agent company.
                        </h1>
                        <p class="max-w-[48rem] text-base leading-7 text-[color:var(--muted-foreground)]">
                          Open the hosted Regent company here. Improve the agent in Techtree, then use Autolaunch when funding comes next.
                        </p>

                        <.home_command command={@install_command} label="Copy install command" />

                        <div class="flex flex-wrap gap-3" data-home-actions>
                          <.link
                            navigate={~p"/app"}
                            id="home-primary-cta"
                            class="pp-home-primary-cta"
                          >
                            <span>{if @current_human, do: "Resume formation", else: "Open app"}</span>
                            <span aria-hidden="true" class="pp-home-primary-cta-arrow">→</span>
                          </.link>
                          <.link
                            navigate={~p"/cli"}
                            class="pp-home-secondary-cta"
                          >
                            View CLI
                          </.link>
                        </div>
                      </div>

                      <div
                        class="relative rounded-[1.7rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] p-5"
                        data-home-panel
                      >
                        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                          The path
                        </p>
                        <div class="mt-4 grid gap-3">
                          <div
                            class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4"
                            data-home-step
                          >
                            <p class="font-display text-xl text-[color:var(--foreground)]">1. Form</p>
                            <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                              Claim identity, add billing, and open the company.
                            </p>
                          </div>
                          <div
                            class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4"
                            data-home-step
                          >
                            <p class="font-display text-xl text-[color:var(--foreground)]">
                              2. Improve
                            </p>
                            <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                              Use Techtree for research, publishing, and collaboration.
                            </p>
                          </div>
                          <div
                            class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--background)] p-4"
                            data-home-step
                          >
                            <p class="font-display text-xl text-[color:var(--foreground)]">3. Fund</p>
                            <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                              Use Autolaunch when launch planning and capital come next.
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </section>

                  <section class="space-y-4" data-home-section>
                    <div class="space-y-3">
                      <p class="text-[10px] uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                        What this page gives you
                      </p>
                      <h2 class="font-display text-[clamp(2rem,5vw,3.2rem)] leading-[0.94] text-[color:var(--foreground)]">
                        One place to open the company, then move on when the next step is ready.
                      </h2>
                    </div>
                    <.home_capability_grid />
                  </section>

                  <section class="space-y-4" data-home-section>
                    <div class="space-y-3">
                      <p class="text-[10px] uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                        Next surfaces
                      </p>
                      <h2 class="font-display text-[clamp(2rem,5vw,3.2rem)] leading-[0.94] text-[color:var(--foreground)]">
                        Improve the agent in Techtree. Fund it in Autolaunch.
                      </h2>
                    </div>
                    <.sister_project_cards />
                  </section>

                  <section
                    class="rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6"
                    data-home-section
                  >
                    <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                      <div>
                        <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                          Operator quickstart
                        </p>
                        <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                          Install the CLI for machine work, open the app for guided company setup, or head to the docs when you need the reference surface.
                        </p>
                      </div>
                      <div class="flex flex-wrap gap-3">
                        <.link
                          navigate={~p"/cli"}
                          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                        >
                          View CLI
                        </.link>
                        <.link
                          navigate={~p"/app"}
                          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                        >
                          Open app
                        </.link>
                        <.link
                          navigate={~p"/docs"}
                          class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--foreground)] transition hover:border-[color:var(--ring)]"
                        >
                          Open docs
                        </.link>
                      </div>
                    </div>
                  </section>
                </main>

                <footer class="space-y-3 rounded-[1.7rem] border border-[color:var(--border)] bg-[color:var(--card)] px-6 py-5">
                  <div class="flex flex-wrap items-center justify-between gap-3 text-sm text-[color:var(--muted-foreground)]">
                    <p>&copy; Regents Labs 2026</p>
                    <Layouts.footer_resource_links />
                  </div>
                  <Layouts.footer_social_links />
                </footer>
              </div>
            <% end %>
          </main>
        </div>
      </Layouts.app>
    <% end %>
    """
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
