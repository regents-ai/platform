defmodule PlatformPhxWeb.App.ProvisioningLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Dashboard
  import PlatformPhxWeb.AppComponents

  @refresh_ms 2_500

  @impl true
  def mount(%{"id" => formation_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Opening company")
     |> assign(:formation_id, parse_formation_id(formation_id))
     |> assign(:formation_data, nil)
     |> assign(:company, nil)
     |> assign(:formation, nil)
     |> load_payload()}
  end

  @impl true
  def handle_info(:refresh_formation_payload, socket) do
    {:noreply, load_payload(socket)}
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
          <section class="space-y-4 rounded-[1.8rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                Opening company
              </p>
              <h2 class="font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
                We could not find that company opening.
              </h2>
              <p class="max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                {provisioning_not_found_copy()}
              </p>
            </div>

            <div class="flex flex-wrap justify-end gap-3">
              <.link
                navigate={~p"/app/formation"}
                class="pp-link-button pp-link-button-slim"
              >
                Back to formation
              </.link>
            </div>
          </section>
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

    socket =
      socket
      |> assign(:formation_data, formation_data)
      |> assign(:formation, formation)
      |> assign(:company, company)
      |> maybe_navigate_to_dashboard()

    if connected?(socket) and formation_active?(formation) do
      Process.send_after(self(), :refresh_formation_payload, @refresh_ms)
    end

    socket
  end

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
