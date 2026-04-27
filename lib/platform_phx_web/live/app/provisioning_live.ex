defmodule PlatformPhxWeb.App.ProvisioningLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform.FormationProgress
  alias PlatformPhx.Dashboard
  import PlatformPhxWeb.AppComponents
  import PlatformPhxWeb.AppComponents.SetupPresenter, only: [setup_snapshot_from_formation: 1]

  @impl true
  def mount(%{"id" => formation_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Opening company")
     |> assign(:formation_id, parse_formation_id(formation_id))
     |> assign(:formation_progress_subscribed?, false)
     |> assign(:formation_data, nil)
     |> assign(:company, nil)
     |> assign(:formation, nil)
     |> load_payload()}
  end

  @impl true
  def handle_info({:formation_progress, %{formation_id: formation_id}}, socket)
      when formation_id == socket.assigns.formation_id do
    {:noreply, load_payload(socket)}
  end

  def handle_info({:formation_progress, _payload}, socket), do: {:noreply, socket}

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
      header_title="Opening company"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-provisioning-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <%= if @company do %>
          <.provisioning_stage company={@company} formation={@formation} />
        <% else %>
          <.setup_blocked_stage
            step={4}
            title="We could not find that company opening."
            summary="This launch link no longer points at an active company opening."
            snapshot={setup_snapshot_from_formation(@formation_data)}
            facts={[
              %{
                icon: "hero-sparkles",
                title: "Launch in progress",
                copy: "Openings appear here while Regents finishes launch."
              },
              %{
                icon: "hero-globe-alt",
                title: "Public page next",
                copy: "The public page opens before the dashboard takes over."
              },
              %{
                icon: "hero-command-line",
                title: "Controls after launch",
                copy: "The company dashboard becomes the next stop."
              }
            ]}
            next_steps={[
              %{
                number: 4,
                title: "Return to launch",
                copy: "Start or reopen a current company launch from the formation step."
              }
            ]}
            blocker_copy={provisioning_not_found_copy()}
            action_label="Back to formation"
            action_path={~p"/app/formation"}
            action_copy="Open the company step again to start a new launch or reopen an active one."
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket) do
    {:ok, result} = Dashboard.agent_formation_payload(socket.assigns.current_human)
    formation_data = result.formation
    formation = formation_by_id(formation_data, socket.assigns.formation_id)
    company = company_for_formation(formation_data, formation)

    socket
    |> assign(:formation_data, formation_data)
    |> assign(:formation, formation)
    |> assign(:company, company)
    |> maybe_subscribe_to_progress(formation)
    |> maybe_navigate_to_dashboard()
  end

  defp maybe_subscribe_to_progress(socket, %{id: formation_id} = formation) do
    if connected?(socket) and formation_active?(formation) and
         socket.assigns.formation_progress_subscribed? == false do
      :ok = FormationProgress.subscribe(formation_id)
      assign(socket, :formation_progress_subscribed?, true)
    else
      socket
    end
  end

  defp maybe_subscribe_to_progress(socket, _formation), do: socket

  defp maybe_navigate_to_dashboard(%{assigns: %{company: company, formation: formation}} = socket) do
    if dashboard_ready?(company, formation) do
      push_navigate(socket, to: ~p"/app/dashboard")
    else
      socket
    end
  end

  defp maybe_navigate_to_dashboard(socket), do: socket

  defp formation_by_id(%{active_formations: formations}, formation_id) when is_list(formations) do
    Enum.find(formations, &(&1.id == formation_id))
  end

  defp formation_by_id(_formation_data, _formation_id), do: nil

  defp company_for_formation(%{owned_companies: companies}, %{claimed_label: claimed_label})
       when is_list(companies) do
    Enum.find(companies, &(&1.slug == claimed_label))
  end

  defp company_for_formation(_formation_data, _formation), do: nil

  defp formation_active?(%{status: status}) when status in ["queued", "running"], do: true
  defp formation_active?(_formation), do: false

  defp dashboard_ready?(%{status: status}, formation)
       when status in ["forming", "published"] and not is_nil(formation) do
    formation.status == "succeeded"
  end

  defp dashboard_ready?(_company, _formation), do: false

  defp parse_formation_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp parse_formation_id(_value), do: nil
end
