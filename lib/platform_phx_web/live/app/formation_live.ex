defmodule PlatformPhxWeb.App.FormationLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Dashboard
  alias PlatformPhx.AgentPlatform.Formation
  import PlatformPhxWeb.AppComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Open company")
     |> assign(:formation_data, nil)
     |> assign(:selected_claimed_label, nil)
     |> assign(:requested_claimed_label, nil)
     |> load_formation_payload()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:requested_claimed_label, normalize_claimed_label(params["claimedLabel"]))
      |> sync_selected_claim()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "change_selected_claim",
        %{"formation_setup" => %{"claimed_label" => claimed_label}},
        socket
      ) do
    {:noreply, assign(socket, :selected_claimed_label, normalize_claimed_label(claimed_label))}
  end

  @impl true
  def handle_event("start_company", _params, socket) do
    case Formation.create_company(socket.assigns.current_human, %{
           "claimedLabel" => socket.assigns.selected_claimed_label
         }) do
      {:accepted, payload} ->
        formation_id = get_in(payload, [:formation, :id])

        {:noreply,
         socket
         |> put_flash(:info, "Your company is opening now.")
         |> push_navigate(to: ~p"/app/provisioning/#{formation_id}")}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
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
      header_eyebrow="App setup"
      header_title="Open company"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-formation-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <%= cond do %>
          <% @formation_data == nil -> %>
            <div class="rounded-[1.6rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6 text-sm text-[color:var(--muted-foreground)]">
              Company creation is unavailable right now.
            </div>
          <% formation_stage_ready?(@formation_data) -> %>
            <.formation_stage
              formation={@formation_data}
              selected_claimed_label={@selected_claimed_label}
              setup_form={setup_form(@selected_claimed_label)}
            />
          <% true -> %>
            <section class="space-y-6 rounded-[1.8rem] border border-[color:var(--border)] bg-[color:var(--card)] p-6">
              <div class="space-y-3">
                <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                  Formation
                </p>
                <h2 class="font-display text-[clamp(2rem,4vw,2.8rem)] leading-[0.95] text-[color:var(--foreground)]">
                  Open the company once the setup steps are ready.
                </h2>
                <p class="max-w-[46rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                  {formation_blocker_copy(@formation_data)}
                </p>
              </div>

              <div class="grid gap-4 lg:grid-cols-2">
                <div class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
                  <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                    Current blocker
                  </p>
                  <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
                    {formation_blocker_copy(@formation_data)}
                  </p>
                </div>

                <div class="rounded-[1.4rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_92%,transparent)] p-5">
                  <p class="text-[10px] uppercase tracking-[0.22em] text-[color:var(--muted-foreground)]">
                    What happens next
                  </p>
                  <p class="mt-3 text-sm leading-6 text-[color:var(--foreground)]">
                    Once the missing step is complete, you can open the company and move to the progress page.
                  </p>
                </div>
              </div>

              <div class="flex flex-wrap justify-end gap-3">
                <.link
                  navigate={formation_next_step_path(@formation_data)}
                  class="inline-flex items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--foreground)] px-4 py-2 text-sm text-[color:var(--background)] transition hover:opacity-90"
                >
                  {formation_next_step_label(@formation_data)}
                </.link>
              </div>
            </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_formation_payload(socket) do
    {:ok, result} = Dashboard.agent_formation_payload(socket.assigns.current_human)

    socket
    |> assign(:formation_data, result.formation)
    |> sync_selected_claim()
  end

  defp sync_selected_claim(%{assigns: %{formation_data: nil}} = socket), do: socket

  defp sync_selected_claim(socket) do
    claims = socket.assigns.formation_data.available_claims
    requested = socket.assigns.requested_claimed_label
    current = socket.assigns.selected_claimed_label

    selected_claimed_label =
      cond do
        requested && Enum.any?(claims, &(&1.label == requested)) -> requested
        current && Enum.any?(claims, &(&1.label == current)) -> current
        true -> claims |> List.first() |> then(&if(&1, do: &1.label, else: nil))
      end

    assign(socket, :selected_claimed_label, selected_claimed_label)
  end

  defp normalize_claimed_label(nil), do: nil

  defp normalize_claimed_label(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_claimed_label(_value), do: nil

  defp setup_form(selected_claimed_label) do
    to_form(%{"claimed_label" => selected_claimed_label}, as: :formation_setup)
  end
end
