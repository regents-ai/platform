defmodule PlatformPhxWeb.App.TrustLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.Agentbook

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Human-backed trust")
      |> assign(:session_id, Map.get(params, "session_id"))
      |> assign(:token, Map.get(params, "token"))
      |> assign(:trust_session, nil)
      |> assign(:trust_error, nil)

    {:ok, load_trust_session(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:session_id, Map.get(params, "session_id"))
      |> assign(:token, Map.get(params, "token"))

    {:noreply, load_trust_session(socket)}
  end

  @impl true
  def handle_event(
        "agentbook_connector_ready",
        %{"session_id" => session_id, "connector_uri" => connector_uri},
        socket
      ) do
    {:noreply, refresh_socket(socket, Agentbook.store_connector_uri(session_id, connector_uri))}
  end

  def handle_event(
        "agentbook_proof_ready",
        %{"session_id" => session_id, "proof" => proof},
        socket
      ) do
    human = socket.assigns.current_human
    token = socket.assigns.token

    result =
      if (human && is_binary(token)) and token != "" do
        Agentbook.complete_session(session_id, token, human, proof)
      else
        {:error,
         {:unauthorized, "Sign in before connecting this agent to a human-backed trust record"}}
      end

    {:noreply, refresh_socket(socket, result)}
  end

  def handle_event(
        "agentbook_failed",
        %{"session_id" => session_id, "message" => message},
        socket
      ) do
    _ = Agentbook.fail_session(session_id, message)

    socket =
      socket
      |> assign(:trust_error, message)
      |> refresh_browser_session()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    session_json =
      if assigns.current_human && assigns.trust_session do
        Jason.encode!(assigns.trust_session)
      else
        ""
      end

    assigns = assign(assigns, :session_json, session_json)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={@current_human}
      chrome={:app}
      active_nav="regents"
      header_eyebrow="Agent trust"
      header_title="Connect a human-backed trust record"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-trust-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <section class="pp-route-card pp-route-card-primary">
          <p class="pp-route-kicker">Human-backed trust</p>
          <h2>Confirm that a real person stands behind this agent.</h2>
          <p>
            This adds an anonymous human-backed trust record to the agent that started this request.
            The person stays private. The agent gains a stronger trust signal.
          </p>
        </section>

        <section class="pp-route-card">
          <%= cond do %>
            <% @trust_error -> %>
              <div class="pp-inline-banner pp-inline-banner-danger">
                <strong>We could not finish this approval.</strong>
                <p>{@trust_error}</p>
              </div>
            <% is_nil(@trust_session) -> %>
              <div class="pp-inline-banner">
                <strong>This link is not ready.</strong>
                <p>Open the latest approval link from the agent and try again.</p>
              </div>
            <% is_nil(@current_human) -> %>
              <div class="pp-inline-banner">
                <strong>Sign in before you continue.</strong>
                <p>Open the app, sign in, then come back to this page to finish the approval.</p>
              </div>
              <div class="pp-action-row">
                <.link navigate="/app/access" class="pp-button pp-button-primary">Open app</.link>
              </div>
            <% @trust_session.status == "registered" -> %>
              <div class="pp-inline-banner pp-inline-banner-success">
                <strong>Trust connected.</strong>
                <p>This agent now carries an anonymous human-backed trust record.</p>
              </div>
            <% @trust_session.status == "failed" -> %>
              <div class="pp-inline-banner pp-inline-banner-danger">
                <strong>Approval stopped.</strong>
                <p>
                  {@trust_session.error_text || "Start a fresh approval from the agent and try again."}
                </p>
              </div>
            <% true -> %>
              <div
                id="platform-trust-flow"
                phx-hook="AgentbookTrustFlow"
                data-session={@session_json}
                class="pp-agentbook-flow"
              >
                <div class="pp-route-card-subtle">
                  <span>Step 1</span>
                  <strong>Open World App</strong>
                  <p>Scan the code or use the direct link on this device.</p>
                </div>

                <div class="pp-agentbook-qr-wrap">
                  <div class="pp-agentbook-qr-frame">
                    <img data-agentbook-qr alt="World App approval code" />
                  </div>
                  <p data-agentbook-uri-text>
                    The approval link will appear here when it is ready.
                  </p>
                </div>
              </div>
          <% end %>
        </section>

        <%= if @trust_session do %>
          <section class="pp-route-card">
            <div class="pp-route-card-subtle">
              <span>Agent wallet</span>
              <strong>{@trust_session.wallet_address}</strong>
            </div>

            <div class="pp-route-card-subtle">
              <span>Status</span>
              <strong>{status_label(@trust_session.status)}</strong>
              <p>{status_copy(@trust_session.status)}</p>
            </div>

            <%= if @trust_session.trust.connected do %>
              <div class="pp-route-card-subtle">
                <span>Trusted agents linked to this person</span>
                <strong>{@trust_session.trust.unique_agent_count}</strong>
                <p>The person stays private. Only the trust record count is shown here.</p>
              </div>
            <% end %>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_trust_session(socket) do
    socket
    |> assign(:trust_session, nil)
    |> assign(:trust_error, nil)
    |> refresh_browser_session()
  end

  defp refresh_browser_session(socket) do
    case browser_session(socket.assigns.session_id, socket.assigns.token) do
      {:ok, trust_session} ->
        socket
        |> assign(:trust_session, trust_session)
        |> assign(:trust_error, nil)

      {:error, {_kind, message}} ->
        socket
        |> assign(:trust_session, nil)
        |> assign(:trust_error, message)
    end
  end

  defp refresh_socket(socket, {:ok, trust_session}) do
    socket
    |> assign(:trust_session, trust_session)
    |> assign(:trust_error, nil)
  end

  defp refresh_socket(socket, {:error, {_kind, message}}) do
    socket
    |> assign(:trust_error, message)
    |> refresh_browser_session()
  end

  defp browser_session(session_id, token)
       when is_binary(session_id) and session_id != "" and is_binary(token) and token != "" do
    Agentbook.get_browser_session(session_id, token)
  end

  defp browser_session(_session_id, _token),
    do: {:error, {:not_found, "Open the approval link from the agent to continue"}}

  defp status_label("pending"), do: "Waiting for approval"
  defp status_label("proof_ready"), do: "Almost done"
  defp status_label("registered"), do: "Connected"
  defp status_label("failed"), do: "Stopped"
  defp status_label(_status), do: "Pending"

  defp status_copy("pending"), do: "Finish the approval in World App."
  defp status_copy("proof_ready"), do: "The approval reached the final step."
  defp status_copy("registered"), do: "This trust record is saved."
  defp status_copy("failed"), do: "This approval needs to be started again."
  defp status_copy(_status), do: "Finish the approval in World App."
end
