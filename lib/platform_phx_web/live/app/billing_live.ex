defmodule PlatformPhxWeb.App.BillingLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Dashboard
  alias PlatformPhx.AgentPlatform.Formation
  import PlatformPhxWeb.AppComponents

  @refresh_ms 2_500

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Add billing")
     |> assign(:formation_data, nil)
     |> assign(:billing_notice, nil)
     |> assign(:selected_claimed_label, nil)
     |> assign(:requested_claimed_label, nil)
     |> assign(:billing_return_state, nil)
     |> load_formation_payload()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:requested_claimed_label, normalize_claimed_label(params["claimedLabel"]))
      |> assign(:billing_return_state, normalize_billing_return_state(params["billing"]))
      |> sync_selected_claim()
      |> maybe_put_billing_notice()

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
  def handle_event("start_billing_setup", _params, socket) do
    case Formation.start_billing_setup_checkout(socket.assigns.current_human, %{
           "claimedLabel" => socket.assigns.selected_claimed_label
         }) do
      {:ok, %{checkout_url: checkout_url}} when is_binary(checkout_url) ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, {_status, message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_info(:refresh_formation_payload, socket) do
    {:noreply, socket |> load_formation_payload() |> maybe_put_billing_notice()}
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
      header_title="Add billing"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-billing-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <%= cond do %>
          <% @formation_data == nil -> %>
            <.setup_blocked_stage
              step={3}
              title="Add billing"
              summary="Billing could not be loaded right now, so this step cannot continue yet."
              snapshot={setup_snapshot_from_formation(nil)}
              facts={[
                %{
                  icon: "hero-credit-card",
                  title: "Usage billing",
                  copy: "Activate payments before launch."
                },
                %{
                  icon: "hero-banknotes",
                  title: "Stored credit",
                  copy: "Launch credit appears here when available."
                },
                %{
                  icon: "hero-rocket-launch",
                  title: "Launch gate",
                  copy: "Company opening waits on billing."
                }
              ]}
              next_steps={[
                %{
                  number: 4,
                  title: "Open company",
                  copy: "Launch starts after billing is active."
                }
              ]}
              blocker_copy="Billing details are unavailable right now."
              action_label="Back to identity"
              action_path={~p"/app/identity"}
              action_copy="Return to the previous step, then come back here once billing is available again."
            />
          <% billing_stage_ready?(@formation_data) -> %>
            <.billing_stage
              formation={@formation_data}
              selected_claimed_label={@selected_claimed_label}
              setup_form={setup_form(@selected_claimed_label)}
              billing_notice={@billing_notice}
            />
          <% true -> %>
            <.setup_blocked_stage
              step={3}
              title="Add billing"
              summary="Add billing after a name is ready."
              snapshot={setup_snapshot_from_formation(@formation_data)}
              facts={[
                %{
                  icon: "hero-credit-card",
                  title: "Usage billing",
                  copy: "Activate payments before launch."
                },
                %{
                  icon: "hero-banknotes",
                  title: "Stored credit",
                  copy: "Launch credit appears here when available."
                },
                %{
                  icon: "hero-rocket-launch",
                  title: "Launch gate",
                  copy: "Company opening waits on billing."
                }
              ]}
              next_steps={[
                %{
                  number: 4,
                  title: "Open company",
                  copy: "Launch starts after billing is active."
                }
              ]}
              blocker_copy={billing_blocker_copy(@formation_data)}
              action_label={billing_next_step_label(@formation_data)}
              action_path={billing_next_step_path(@formation_data)}
              action_copy="Finish the missing name step, then return here to activate billing and continue."
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_formation_payload(socket) do
    {:ok, result} = Dashboard.agent_formation_payload(socket.assigns.current_human)

    socket =
      socket
      |> assign(:formation_data, result.formation)
      |> sync_selected_claim()

    if connected?(socket) and awaiting_billing_ready?(socket) do
      Process.send_after(self(), :refresh_formation_payload, @refresh_ms)
    end

    socket
  end

  defp awaiting_billing_ready?(%{
         assigns: %{
           billing_return_state: :success,
           formation_data: %{billing_account: billing_account}
         }
       }) do
    billing_account.connected != true
  end

  defp awaiting_billing_ready?(_socket), do: false

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

  defp maybe_put_billing_notice(%{assigns: %{billing_return_state: nil}} = socket), do: socket

  defp maybe_put_billing_notice(socket) do
    notice =
      case socket.assigns.billing_return_state do
        :success ->
          if socket.assigns.formation_data &&
               socket.assigns.formation_data.billing_account.connected do
            %{tone: :success, message: "Billing is ready. You can continue to company creation."}
          else
            %{
              tone: :info,
              message: "Finishing billing setup now. This page will update automatically."
            }
          end

        :cancel ->
          %{tone: :error, message: "Billing setup was cancelled."}
      end

    assign(socket, :billing_notice, notice)
  end

  defp normalize_billing_return_state("success"), do: :success
  defp normalize_billing_return_state("cancel"), do: :cancel
  defp normalize_billing_return_state(_value), do: nil

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
