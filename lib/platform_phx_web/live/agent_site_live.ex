defmodule PlatformPhxWeb.AgentSiteLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.AgentPlatformComponents
  alias PlatformPhxWeb.CompanyRoomComponents
  alias PlatformPhxWeb.CompanyRoomSupport

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    agent = AgentPlatform.get_public_agent(slug)
    {owner_company, billing_account} = owner_panel(agent, socket.assigns.current_human)
    room_agent = room_agent(agent, socket.assigns.current_human)

    if connected?(socket) and room_agent do
      :ok = PlatformPhx.Xmtp.subscribe(PlatformPhx.Xmtp.company_room_key(room_agent))
    end

    {:ok,
     socket
     |> assign(:page_title, "Agent Preview")
     |> assign(:agent, agent)
     |> assign(:owner_company, owner_company)
     |> assign(:billing_account, billing_account)
     |> assign(
       :xmtp_room,
       CompanyRoomSupport.load_room_panel(room_agent, socket.assigns.current_human)
     )
     |> CompanyRoomSupport.assign_message_form()
     |> assign(:slug, slug)}
  end

  @impl true
  def handle_event("pause_company", %{"slug" => slug}, socket) do
    case Formation.pause_sprite(socket.assigns.current_human, slug) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company paused.")
         |> reload_agent_preview()}

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
         |> reload_agent_preview()}

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
    {:noreply, reload_agent_preview(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
        id="agent-site-preview-shell"
        class="pp-home-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="p-4 sm:p-6 lg:p-8">
          <%= if @agent do %>
            <div class="space-y-6">
              <AgentPlatformComponents.public_agent_page
                agent={AgentPlatform.serialize_agent(@agent, :public)}
                owner_company={@owner_company}
                billing_account={@billing_account}
                launch_home_path={~p"/agent-formation?stage=setup&claimedLabel=#{@slug}"}
              />
              <CompanyRoomComponents.company_room
                :if={@xmtp_room}
                room={@xmtp_room}
                form={@xmtp_message_form}
              />
            </div>
          <% else %>
            <div class="mx-auto max-w-[760px] rounded-[1.75rem] border border-[color:var(--border)] bg-[color:var(--card)] p-8">
              <p class="pp-home-kicker">Agent Preview</p>
              <h1 class="pp-route-panel-title mt-3">Agent not found</h1>
              <p class="pp-panel-copy mt-3">
                No published agent matches <code>{@slug}</code>.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp reload_agent_preview(socket) do
    agent = AgentPlatform.get_public_agent(socket.assigns.slug)
    {owner_company, billing_account} = owner_panel(agent, socket.assigns.current_human)
    room_agent = room_agent(agent, socket.assigns.current_human)

    socket
    |> assign(:agent, agent)
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

  defp owner_panel(_agent, _current_human), do: {nil, nil}

  defp room_agent(%{slug: slug}, %{} = current_human),
    do: AgentPlatform.get_owned_agent(current_human, slug) || AgentPlatform.get_public_agent(slug)

  defp room_agent(%{slug: slug}, _current_human), do: AgentPlatform.get_public_agent(slug)
  defp room_agent(_agent, _current_human), do: nil

  defp room_key(socket) do
    socket
    |> room_agent_from_socket()
    |> case do
      nil -> nil
      agent -> PlatformPhx.Xmtp.company_room_key(agent)
    end
  end

  defp room_agent_from_socket(socket),
    do: room_agent(socket.assigns.agent, socket.assigns.current_human)

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
