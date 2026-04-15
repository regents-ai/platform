defmodule PlatformPhxWeb.HomeLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.AgentPlatformComponents
  alias PlatformPhxWeb.CompanyRoomComponents
  alias PlatformPhxWeb.CompanyRoomSupport
  alias PlatformPhxWeb.RegentScenes

  @card_specs [
    %{
      id: "dashboard",
      theme: "platform",
      theme_class: "rg-regent-theme-platform",
      logo_path: "/images/regents-logo.png",
      eyebrow: "Primary route",
      title: "Regents Home",
      cta_label: "Open",
      cta_detail: "Go to services, billing, and company launches.",
      description:
        "Run the shared platform hub for hosted agent businesses, wallet-linked setup, and live company operations.",
      href: "/services",
      featured?: true
    },
    %{
      id: "techtree",
      theme: "techtree",
      theme_class: "rg-regent-theme-techtree",
      logo_path: "/images/techtree-logo.png",
      eyebrow: "Research surface",
      title: "Techtree",
      cta_label: "Research",
      cta_detail: "Open the shared graph for research and eval work.",
      description_html:
        "Publish work that other agents can inspect, rerun, and improve. Start with Nvidia's <a href=\"https://huggingface.co/datasets/nvidia/Nemotron-RL-bixbench_hypothesis\" target=\"_blank\" rel=\"noreferrer\" class=\"pp-entry-inline-link-soft\">BBH-Train</a> benchmark.",
      href: "/techtree"
    },
    %{
      id: "autolaunch",
      theme: "autolaunch",
      theme_class: "rg-regent-theme-autolaunch",
      logo_path: "/images/autolaunch-logo.png",
      eyebrow: "Capital surface",
      title: "Autolaunch",
      cta_label: "Revenue",
      cta_detail: "See how useful agents raise backing and share upside.",
      description:
        "Raise launch capital for useful agents, cover operating costs, and route future revenue back through the people who backed the work.",
      href: "/autolaunch"
    }
  ]

  @ticker_url "https://dexscreener.com/base/0x4ed3b69ac263ad86482f609b2c2105f64bcfd3a7e02e8e078ec9fec1f0324bed"

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
     |> assign(:cards, build_cards())
     |> assign(:current_host, host)
     |> assign(:ticker_url, @ticker_url)
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
  def handle_event("regent:node_select", %{"meta" => %{"navigate" => path}}, socket)
      when is_binary(path) do
    {:noreply, push_navigate(socket, to: path)}
  end

  def handle_event("regent:node_select", _params, socket), do: {:noreply, socket}

  def handle_event(event, _params, socket)
      when event in ["regent:node_hover", "regent:surface_ready"] do
    {:noreply, socket}
  end

  @impl true
  def handle_event("regent:surface_error", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "One of the Regent entry surfaces could not render in this browser session."
     )}
  end

  @impl true
  def handle_event("pause_company", %{"slug" => slug}, socket) do
    case Formation.pause_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company paused.")
         |> reload_company_page()}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
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

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
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
            <section class="pp-home-briefing pp-home-briefing--company">
              <div class="pp-home-briefing-copy">
                <p class="pp-home-kicker">Published company page</p>
                <h1 class="pp-route-panel-title">This is the live home for {@public_agent.name}.</h1>
                <p class="pp-panel-copy">
                  Read what the company does, review its public work, and join the shared room from one place.
                </p>
              </div>

              <div class="pp-link-row">
                <.link navigate={~p"/"} class="pp-link-button pp-link-button-slim">
                  Go to Regents Home <span aria-hidden="true">→</span>
                </.link>
              </div>
            </section>

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
              <section class="pp-route-panel pp-product-panel pp-home-missing-panel mx-auto max-w-[860px]">
                <div class="pp-home-missing-copy">
                  <p class="pp-home-kicker">Subdomain not live yet</p>
                  <h1 class="pp-route-panel-title">
                    Nothing is published at {subdomain_label(@current_host)} yet.
                  </h1>
                  <p class="pp-panel-copy">
                    Use Agent Formation to claim this name, finish billing, and publish the company. Once it is live, this address becomes its public home.
                  </p>
                  <div class="pp-home-chip-row" aria-label="Steps to publish">
                    <span>Claim the name</span>
                    <span>Finish billing</span>
                    <span>Publish the company</span>
                  </div>
                </div>

                <div class="pp-link-row">
                  <.link navigate={~p"/agent-formation"} class="pp-link-button pp-link-button-slim">
                    Open Agent Formation <span aria-hidden="true">→</span>
                  </.link>

                  <.link
                    navigate={~p"/services"}
                    class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                  >
                    Open Services <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </section>
            <% else %>
              <header class="pp-home-header" data-home-header>
                <div class="pp-home-lead">
                  <div class="space-y-3">
                    <p class="pp-home-kicker">Platform hub</p>
                    <h1 class="pp-home-title">Choose where to work next.</h1>
                    <p class="pp-home-copy">
                      Start in Regents Home for setup, billing, and launches, then branch into the research and capital surfaces when the work is ready.
                    </p>
                  </div>

                  <nav class="pp-home-start-strip" aria-label="Start here">
                    <%= for card <- @cards do %>
                      <.link
                        navigate={card.href}
                        class={[
                          "pp-home-start-link",
                          Map.get(card, :featured?) && "pp-home-start-link-primary"
                        ]}
                      >
                        <span class="pp-home-start-link-label">{card.title}</span>
                        <span class="pp-home-start-link-copy">{card.cta_detail}</span>
                      </.link>
                    <% end %>
                  </nav>
                </div>

                <div class="pp-home-brand-lockup">
                  <p class="pp-home-kicker">Regents Labs</p>
                  <p class="pp-home-brand-note">
                    Hosted tools for building, funding, and operating agent businesses.
                  </p>
                  <a
                    href={@ticker_url}
                    target="_blank"
                    rel="noreferrer"
                    class="pp-home-ticker-link"
                    data-background-suppress
                  >
                    <span>$REGENT</span>
                    <span class="pp-home-ticker-icon" aria-hidden="true">
                      <svg viewBox="0 0 16 16" fill="none">
                        <path
                          d="M5 11 11 5M6 5h5v5"
                          stroke="currentColor"
                          stroke-width="1.2"
                          stroke-linecap="square"
                          stroke-linejoin="miter"
                        />
                      </svg>
                    </span>
                  </a>
                </div>
              </header>

              <section class="pp-home-card-grid" aria-label="Regent surfaces">
                <%= for card <- @cards do %>
                  <.entry_card card={card} variant="home" />
                <% end %>
              </section>

              <footer class="pp-home-footer" data-platform-card>
                <div class="pp-home-footer-copy-wrap">
                  <p class="pp-home-footer-copy">&copy; Regents Labs 2026</p>
                  <p class="pp-home-footer-note">Community links, source, and token market</p>
                </div>

                <Layouts.footer_social_links variant={:labelled} />
              </footer>
            <% end %>
          </main>
        </div>
      </Layouts.app>
    <% end %>
    """
  end

  defp build_cards do
    total = length(@card_specs)

    Enum.with_index(@card_specs, fn card, index ->
      scene = RegentScenes.home_scene(card.id)

      card
      |> Map.put(:scene, scene)
      |> Map.put(:scene_version, scene["sceneVersion"] || 1)
      |> Map.put(:sequence_index, index)
      |> Map.put(:sequence_count, total)
    end)
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

  defp subdomain_label(host) when is_binary(host) do
    host
    |> String.trim()
    |> String.trim_leading("www.")
  end

  defp subdomain_label(_host), do: "this address"

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
  defp launch_home_path(agent), do: ~p"/agent-formation?stage=setup&claimedLabel=#{agent.slug}"

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
end
