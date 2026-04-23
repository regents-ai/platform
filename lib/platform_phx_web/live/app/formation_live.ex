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
            <.setup_blocked_stage
              step={4}
              title="Open company"
              summary="Company opening could not be loaded right now, so launch cannot continue yet."
              snapshot={setup_snapshot_from_formation(nil)}
              facts={[
                %{
                  icon: "hero-identification",
                  title: "Chosen identity",
                  copy: "A ready name becomes the company identity."
                },
                %{
                  icon: "hero-credit-card",
                  title: "Payments active",
                  copy: "Billing must already be on."
                },
                %{
                  icon: "hero-building-office-2",
                  title: "Hosted launch",
                  copy: "Regents opens the company for you."
                }
              ]}
              next_steps={[
                %{
                  number: 4,
                  title: "Launch progress",
                  copy: "You move to live progress after opening."
                }
              ]}
              blocker_copy="Company opening is unavailable right now."
              action_label="Back to billing"
              action_path={~p"/app/billing"}
              action_copy="Return to the previous step, then come back here when company opening is available again."
            />
          <% formation_stage_ready?(@formation_data) -> %>
            <.formation_stage
              formation={@formation_data}
              selected_claimed_label={@selected_claimed_label}
              setup_form={setup_form(@selected_claimed_label)}
            />
          <% true -> %>
            <.setup_blocked_stage
              step={4}
              title="Open company"
              summary="Company opening becomes available once access, identity, and billing are all ready."
              snapshot={setup_snapshot_from_formation(@formation_data)}
              facts={[
                %{
                  icon: "hero-identification",
                  title: "Chosen identity",
                  copy: "A ready name becomes the company identity."
                },
                %{
                  icon: "hero-credit-card",
                  title: "Payments active",
                  copy: "Billing must already be on."
                },
                %{
                  icon: "hero-building-office-2",
                  title: "Hosted launch",
                  copy: "Regents opens the company for you."
                }
              ]}
              next_steps={[
                %{
                  number: 4,
                  title: "Launch progress",
                  copy: "You move to live progress after opening."
                }
              ]}
              blocker_copy={formation_blocker_copy(@formation_data)}
              action_label={formation_next_step_label(@formation_data)}
              action_path={formation_next_step_path(@formation_data)}
              action_copy="Finish the missing setup step, then come back here to launch the company."
              readiness={Map.get(@formation_data, :readiness)}
            />
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
