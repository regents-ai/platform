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

    assigns =
      assigns
      |> assign(:session_json, session_json)
      |> assign(:trust_flow_hook, trust_flow_hook(assigns.current_human, assigns.trust_session))

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
        <div class="pp-route-stage space-y-5">
          <section class="pp-route-grid" data-dashboard-block>
            <article class="pp-route-panel pp-product-panel pp-route-panel-span overflow-hidden px-5 py-5 lg:px-6 lg:py-6">
              <div class="grid gap-6 xl:grid-cols-[minmax(0,1.18fr)_24rem]">
                <div class="space-y-8">
                  <div class="flex flex-col gap-5 lg:flex-row lg:items-start">
                    <div class="flex h-[6.9rem] w-[6.9rem] shrink-0 items-center justify-center rounded-[1.35rem] border border-[color:var(--border)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_86%,white_14%),color-mix(in_oklch,var(--card)_88%,var(--background)_12%))] shadow-[inset_0_1px_0_color-mix(in_oklch,white_45%,transparent)]">
                      <span class="inline-flex h-[5rem] w-[5rem] items-center justify-center rounded-[1.2rem] bg-[radial-gradient(circle_at_30%_25%,color-mix(in_oklch,white_74%,transparent),transparent_45%),linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_12%,var(--background)_88%),color-mix(in_oklch,var(--background)_96%,var(--card)_4%))] text-[color:var(--brand-ink)]">
                        <.icon name="hero-shield-check" class="h-11 w-11" />
                      </span>
                    </div>

                    <div class="min-w-0 space-y-3">
                      <h1 class="font-display text-[clamp(2.6rem,5vw,4.2rem)] leading-[0.9] tracking-[-0.06em] text-[color:var(--foreground)]">
                        Human-backed trust
                      </h1>
                      <p class="text-[1.45rem] leading-none tracking-[-0.03em] text-[color:var(--foreground)]">
                        Connect a human-backed trust record
                      </p>
                      <p class="max-w-[38rem] text-[1.02rem] leading-7 text-[color:var(--muted-foreground)]">
                        Confirm that a real person stands behind this agent.
                      </p>
                    </div>
                  </div>

                  <div class="grid gap-4 sm:grid-cols-3">
                    <%= for card <- trust_principles() do %>
                      <section class="rounded-[1.25rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_86%,var(--card)_14%)] px-4 py-4">
                        <div class="flex items-start gap-3">
                          <span class="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                            <.icon name={card.icon} class="h-5 w-5" />
                          </span>
                          <div class="space-y-2">
                            <p class="font-display text-[1.02rem] leading-none text-[color:var(--foreground)]">
                              {card.title}
                            </p>
                            <p class="text-sm leading-7 text-[color:var(--muted-foreground)]">
                              {card.copy}
                            </p>
                          </div>
                        </div>
                      </section>
                    <% end %>
                  </div>
                </div>

                <aside class="rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] px-5 py-4">
                  <div class="space-y-1">
                    <p class="font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                      Connection summary
                    </p>
                  </div>
                  <div class="mt-4 divide-y divide-[color:color-mix(in_oklch,var(--border)_80%,transparent)] rounded-[1.1rem] border border-[color:var(--border)] bg-[color:var(--card)]">
                    <%= for card <- trust_status_cards(@trust_session) do %>
                      <section class="flex items-start gap-4 px-4 py-4">
                        <span class="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-[0.95rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                          <.icon name={card.icon} class="h-5 w-5" />
                        </span>
                        <div class="min-w-0 flex-1 space-y-2">
                          <div class="flex items-start justify-between gap-3">
                            <p class="text-[0.92rem] leading-6 text-[color:var(--foreground)]">
                              {card.label}
                            </p>
                            <span class={["text-sm leading-6", card.value_class]}>
                              {card.value}
                            </span>
                          </div>
                          <div class="flex items-center justify-between gap-3">
                            <p class="min-w-0 flex-1 break-all text-[1.02rem] leading-7 text-[color:var(--brand-ink)]">
                              {card.copy}
                            </p>
                            <span
                              :if={card.meta}
                              class="shrink-0 text-sm leading-6 text-[color:var(--muted-foreground)]"
                            >
                              {card.meta}
                            </span>
                          </div>
                        </div>
                      </section>
                    <% end %>
                  </div>
                </aside>
              </div>
            </article>
          </section>

          <section class="pp-route-grid" data-dashboard-block>
            <div class="grid gap-4 xl:grid-cols-[minmax(0,1.22fr)_19.25rem]">
              <article class="pp-route-panel pp-product-panel pp-route-panel-span px-5 py-5 lg:px-6 lg:py-6">
                <div class="space-y-5">
                  <div class="space-y-2">
                    <h2 class="font-display text-[1.9rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                      Approve trust for this agent
                    </h2>
                  </div>

                  <div class="grid grid-cols-4 gap-4">
                    <%= for step <- trust_flow_steps() do %>
                      <div class="space-y-3">
                        <div class="flex items-center gap-3">
                          <span class={[
                            "inline-flex h-8 w-8 items-center justify-center rounded-full border text-sm",
                            step.number == "1" &&
                              "border-[color:var(--brand-ink)] bg-[color:var(--brand-ink)] text-[color:var(--background)]",
                            step.number != "1" &&
                              "border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]"
                          ]}>
                            {step.number}
                          </span>
                          <div class="h-px flex-1 bg-[linear-gradient(90deg,color-mix(in_oklch,var(--border)_84%,transparent),transparent)] last:hidden">
                          </div>
                        </div>
                        <p class={[
                          "text-sm leading-6",
                          step.number == "1" && "text-[color:var(--brand-ink)]",
                          step.number != "1" && "text-[color:var(--muted-foreground)]"
                        ]}>
                          {step.title}
                        </p>
                      </div>
                    <% end %>
                  </div>

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
                        <p>Open setup, sign in, then come back here to finish the approval.</p>
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
                          {@trust_session.error_text ||
                            "Start a fresh approval from the agent and try again."}
                        </p>
                      </div>
                    <% true -> %>
                      <%!-- no inline banner --%>
                  <% end %>

                  <div
                    id="platform-trust-flow"
                    phx-hook={@trust_flow_hook}
                    data-session={@session_json}
                    class="grid gap-5 rounded-[1.35rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] p-4 lg:grid-cols-[15rem_minmax(0,1fr)_19rem]"
                  >
                    <div class="space-y-4">
                      <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                        <div class="pp-agentbook-qr-wrap">
                          <div class="pp-agentbook-qr-frame">
                            <img data-agentbook-qr alt="Approval code" />
                          </div>
                        </div>
                      </div>

                      <div class="space-y-3 rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] p-4">
                        <div class="h-px bg-[linear-gradient(90deg,color-mix(in_oklch,var(--border)_84%,transparent),transparent)]">
                        </div>
                        <button
                          id="platform-trust-copy-link"
                          type="button"
                          phx-hook="ClipboardCopy"
                          data-copy-text={
                            if(@trust_session, do: @trust_session.deep_link_uri || "", else: "")
                          }
                          class="inline-flex w-full items-center justify-center gap-2 rounded-[0.9rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                        >
                          <.icon name="hero-link" class="h-4 w-4" />
                          <span>Copy connection link</span>
                        </button>
                      </div>
                    </div>

                    <div class="space-y-4">
                      <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] px-5 py-5">
                        <h3 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                          1. Connect from your device
                        </h3>
                        <p class="mt-4 text-[0.98rem] leading-7 text-[color:var(--muted-foreground)]">
                          Open the Regents app on your phone or tablet and scan this code to connect your identity to this agent.
                        </p>

                        <div class="mt-5 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--brand-ink)_18%,var(--border)_82%)] bg-[color:color-mix(in_oklch,var(--brand-ink)_6%,var(--background)_94%)] px-4 py-3">
                          <div class="flex items-start gap-3">
                            <span class="mt-0.5 inline-flex h-5 w-5 items-center justify-center rounded-full bg-[color:var(--brand-ink)] text-[color:var(--background)]">
                              <.icon name="hero-information-circle" class="h-3.5 w-3.5" />
                            </span>
                            <div class="text-sm leading-6 text-[color:var(--brand-ink)]">
                              Connection is secure and private.
                              <span class="block text-[color:var(--muted-foreground)]">
                                No personal details are shared with the agent.
                              </span>
                            </div>
                          </div>
                        </div>

                        <div class="mt-6">
                          <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                            Or connect another way
                          </p>
                          <p
                            data-agentbook-uri-text
                            class="mt-3 min-h-[3rem] border-t border-[color:color-mix(in_oklch,var(--border)_84%,transparent)] pt-3 text-sm leading-6 text-[color:var(--muted-foreground)]"
                          >
                            The approval link will appear here when it is ready.
                          </p>
                        </div>

                        <%= if is_nil(@current_human) do %>
                          <div class="mt-5">
                            <.link navigate="/app/access" class="pp-link-button pp-link-button-slim">
                              Continue setup <span aria-hidden="true">→</span>
                            </.link>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <div class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_84%,var(--card)_16%)] p-4">
                      <p class="font-display text-[1.15rem] leading-none text-[color:var(--foreground)]">
                        Approval status
                      </p>
                      <div class="mt-4 space-y-3">
                        <%= for item <- trust_progress_items(@trust_session, @current_human) do %>
                          <section class="rounded-[1rem] border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-4">
                            <div class="flex items-start gap-3">
                              <span class="inline-flex h-7 w-7 shrink-0 rounded-full border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)]">
                              </span>
                              <div>
                                <p class="text-sm leading-6 text-[color:var(--foreground)]">
                                  {item.title}
                                </p>
                                <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                                  {item.copy}
                                </p>
                              </div>
                            </div>
                          </section>
                        <% end %>
                      </div>

                      <p class="mt-4 flex items-center gap-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                        <.icon name="hero-lock-closed" class="h-4 w-4" />
                        You can revoke trust at any time.
                      </p>
                    </div>
                  </div>
                </div>
              </article>

              <aside class="space-y-4">
                <article class="pp-route-panel pp-product-panel px-5 py-5">
                  <h2 class="font-display text-[1.6rem] leading-none tracking-[-0.04em] text-[color:var(--foreground)]">
                    Connection states
                  </h2>

                  <div class="mt-5 space-y-4">
                    <%= for card <- trust_connection_state_cards(@trust_session, @current_human) do %>
                      <section class="rounded-[1.2rem] border border-[color:var(--border)] bg-[color:var(--card)] px-4 py-4">
                        <div class="flex items-start gap-3">
                          <span class={[
                            "mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border",
                            card.icon_class
                          ]}>
                            <.icon name={card.icon} class="h-4 w-4" />
                          </span>
                          <div class="min-w-0 flex-1">
                            <p class={["text-[1rem] leading-none", card.title_class]}>{card.title}</p>
                            <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
                              {card.copy}
                            </p>
                            <div :if={card.action} class="mt-4">
                              <.link
                                navigate={card.action.href}
                                class="pp-link-button pp-link-button-slim"
                              >
                                {card.action.label}
                              </.link>
                            </div>
                          </div>
                        </div>
                      </section>
                    <% end %>
                  </div>
                </article>
              </aside>
            </div>
          </section>

          <section class="pp-route-grid" data-dashboard-block>
            <div class="grid gap-4 xl:grid-cols-4">
              <%= for item <- trust_storage_cards() do %>
                <article class="pp-route-panel pp-product-panel px-5 py-5">
                  <div class="flex items-start gap-3">
                    <span class="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-[0.95rem] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                      <.icon name={item.icon} class="h-5 w-5" />
                    </span>
                    <div class="min-w-0">
                      <h3 class="font-display text-[1.2rem] leading-none tracking-[-0.03em] text-[color:var(--foreground)]">
                        {item.label}
                      </h3>
                      <div class="mt-4 space-y-2 text-sm leading-7 text-[color:var(--muted-foreground)]">
                        <%= for line <- item.lines do %>
                          <p>{line}</p>
                        <% end %>
                      </div>
                      <div :if={item.link} class="mt-5">
                        <.link navigate={item.link.href} class="pp-link-button pp-link-button-slim">
                          {item.link.label} <span aria-hidden="true">→</span>
                        </.link>
                      </div>
                    </div>
                  </div>
                </article>
              <% end %>
            </div>
          </section>
        </div>
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

  defp trust_flow_hook(nil, _trust_session), do: nil
  defp trust_flow_hook(_current_human, nil), do: nil

  defp trust_flow_hook(_current_human, %{status: status}) when status in ["registered", "failed"],
    do: nil

  defp trust_flow_hook(_current_human, _trust_session), do: "AgentbookTrustFlow"

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

  defp status_copy("pending"), do: "Finish the approval on your device."
  defp status_copy("proof_ready"), do: "The approval reached the final step."
  defp status_copy("registered"), do: "This trust record is saved."
  defp status_copy("failed"), do: "This approval needs to be started again."
  defp status_copy(_status), do: "Finish the approval on your device."

  defp trust_principles do
    [
      %{
        icon: "hero-lock-closed",
        title: "Private by design",
        copy:
          "Your identity is never public. We only store what is needed to vouch for your agent."
      },
      %{
        icon: "hero-shield-check",
        title: "Human assurance",
        copy: "A verified person can stand behind this agent and approve or revoke trust."
      },
      %{
        icon: "hero-eye-slash",
        title: "Your control",
        copy: "You decide which agents are linked to your record and when."
      }
    ]
  end

  defp trust_status_cards(trust_session) do
    [
      %{
        icon: "hero-wallet",
        label: "Agent wallet",
        value:
          if(trust_session && trust_session.wallet_address, do: "Connected", else: "Waiting"),
        value_class:
          if(trust_session && trust_session.wallet_address,
            do: "text-[color:#159957]",
            else: "text-[color:var(--muted-foreground)]"
          ),
        copy:
          (trust_session && abbreviated_wallet(trust_session.wallet_address)) ||
            "No wallet linked yet",
        meta: nil
      },
      %{
        icon: "hero-shield-check",
        label: "Status",
        value: (trust_session && status_label(trust_session.status)) || "Pending",
        value_class:
          if(trust_session && trust_session.status == "registered",
            do: "text-[color:#159957]",
            else: "text-[color:var(--brand-ink)]"
          ),
        copy:
          (trust_session && approval_badge_label(trust_session.status)) || "Waiting for approval",
        meta: trust_session && trust_status_meta(trust_session.status)
      },
      %{
        icon: "hero-user-group",
        label: "Trusted agents linked to this person",
        value: "Manage",
        value_class: "text-[color:var(--brand-ink)]",
        copy: Integer.to_string(linked_agent_count(trust_session)),
        meta: nil
      }
    ]
  end

  defp trust_flow_steps do
    [
      %{number: "1", title: "Connect"},
      %{number: "2", title: "Review"},
      %{number: "3", title: "Approve"},
      %{number: "4", title: "Complete"}
    ]
  end

  defp trust_storage_cards do
    [
      %{
        icon: "hero-shield-check",
        label: "What this means",
        lines: [
          "You are confirming you are a real person standing behind this agent.",
          "The trust mark is visible only as a trust signal."
        ],
        link: %{href: "/docs", label: "Learn more about trust"}
      },
      %{
        icon: "hero-lock-closed",
        label: "What we store",
        lines: [
          "Proof you are a unique human.",
          "Your approval for this agent.",
          "Timestamps and revocation state.",
          "We do not store names, documents, or photos."
        ],
        link: nil
      },
      %{
        icon: "hero-eye-slash",
        label: "What stays private",
        lines: [
          "Your identity.",
          "Your personal details.",
          "Your device information.",
          "We never share your private data."
        ],
        link: nil
      },
      %{
        icon: "hero-user-circle",
        label: "Your control",
        lines: [
          "You can approve, revoke, or move trust to another agent at any time."
        ],
        link: %{href: "/app/dashboard", label: "Manage trusted agents"}
      }
    ]
  end

  defp trust_progress_items(trust_session, current_human) do
    case {trust_session, current_human} do
      {nil, _} ->
        [
          %{
            icon: "hero-link",
            title: "Waiting for connection",
            copy: "Open the approval link from the agent to begin."
          },
          %{
            icon: "hero-arrow-path",
            title: "Reviewing",
            copy: "The review step appears after the link is opened on your device."
          },
          %{
            icon: "hero-check-badge",
            title: "Complete",
            copy: "This page will update once trust is connected."
          }
        ]

      {_session, nil} ->
        [
          %{
            icon: "hero-user",
            title: "Not signed in",
            copy: "Sign in on this device before you continue."
          },
          %{
            icon: "hero-link",
            title: "Connection ready",
            copy: "Your approval link is waiting."
          },
          %{
            icon: "hero-check-badge",
            title: "Complete",
            copy: "Finish sign-in, then come back to this page."
          }
        ]

      {%{status: "registered"}, _} ->
        [
          %{
            icon: "hero-check-circle",
            title: "Connected",
            copy: "The request and the proof both finished successfully."
          },
          %{
            icon: "hero-shield-check",
            title: "Trusted",
            copy: "This agent now carries your human-backed trust record."
          },
          %{
            icon: "hero-clock",
            title: "Saved",
            copy: "The approval is stored and can be managed later."
          }
        ]

      {%{status: "failed", error_text: error_text}, _} ->
        [
          %{
            icon: "hero-exclamation-triangle",
            title: "Connection failed",
            copy: error_text || "Try again or get a new code."
          },
          %{
            icon: "hero-arrow-path",
            title: "Start again",
            copy: "Open a fresh approval link from the agent."
          },
          %{
            icon: "hero-user",
            title: "Need help",
            copy: "If the problem keeps repeating, confirm you are signed in on this device."
          }
        ]

      {%{status: "proof_ready"}, _} ->
        [
          %{
            icon: "hero-link",
            title: "Connected",
            copy: "Your device is connected and the request is in review."
          },
          %{
            icon: "hero-shield-check",
            title: "Approving",
            copy: "Finish the trust approval on your device."
          },
          %{
            icon: "hero-clock",
            title: "Complete",
            copy: "This page will update as soon as the final step lands."
          }
        ]

      {%{status: "pending"}, _} ->
        [
          %{
            icon: "hero-link",
            title: "Waiting for connection",
            copy: "Scan the code on your device to begin."
          },
          %{
            icon: "hero-shield-check",
            title: "Reviewing",
            copy: "Read the request and confirm it belongs to this agent."
          },
          %{
            icon: "hero-check-badge",
            title: "Complete",
            copy: "Approve the request to finish the trust link."
          }
        ]

      {session, _} ->
        [
          %{
            icon: "hero-link",
            title: status_label(session.status),
            copy: status_copy(session.status)
          },
          %{
            icon: "hero-shield-check",
            title: "Reviewing",
            copy: "Keep going on your device if more steps appear."
          },
          %{
            icon: "hero-check-badge",
            title: "Complete",
            copy: "This page updates automatically when the approval finishes."
          }
        ]
    end
  end

  defp trust_connection_state_cards(trust_session, current_human) do
    [
      %{
        icon: "hero-check",
        icon_class:
          "border-[color:color-mix(in_oklch,#159957_30%,transparent)] bg-[color:color-mix(in_oklch,#159957_10%,transparent)] text-[color:#159957]",
        title: "Success",
        title_class: "text-[color:var(--foreground)]",
        copy:
          if(trust_session && trust_session.status == "registered",
            do: "Connected and saved for this agent.",
            else: "Connected and ready to review. You can approve trust."
          ),
        action: nil
      },
      %{
        icon: "hero-exclamation-triangle",
        icon_class:
          "border-[color:color-mix(in_oklch,#d34b47_28%,transparent)] bg-[color:color-mix(in_oklch,#d34b47_8%,transparent)] text-[color:#d34b47]",
        title: "Connection failed",
        title_class: "text-[color:#c13631]",
        copy:
          (trust_session && trust_session.status == "failed" &&
             (trust_session.error_text ||
                "We couldn't complete the connection. Try again or get a new code.")) ||
            "We couldn't complete the connection. Try again or get a new code.",
        action: nil
      },
      %{
        icon: "hero-user",
        icon_class:
          "border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--muted-foreground)]",
        title: "Not signed in",
        title_class: "text-[color:var(--foreground)]",
        copy: "Sign in to your Regents account on your device to continue.",
        action:
          if(is_nil(current_human),
            do: %{href: "/app/access", label: "Continue setup"},
            else: nil
          )
      }
    ]
  end

  defp linked_agent_count(trust_session) do
    if trust_session && get_in(trust_session, [:trust, :connected]) do
      get_in(trust_session, [:trust, :unique_agent_count]) || 0
    else
      0
    end
  end

  defp approval_badge_label("registered"), do: "Approved"
  defp approval_badge_label("proof_ready"), do: "Reviewing"
  defp approval_badge_label("failed"), do: "Needs attention"
  defp approval_badge_label("pending"), do: "Waiting for connection"
  defp approval_badge_label(_status), do: "Waiting for approval"

  defp trust_status_meta("registered"), do: "Ready"
  defp trust_status_meta("proof_ready"), do: "In review"
  defp trust_status_meta("failed"), do: "Try again"
  defp trust_status_meta("pending"), do: nil
  defp trust_status_meta(_status), do: nil

  defp abbreviated_wallet(nil), do: "Waiting for link"

  defp abbreviated_wallet(wallet_address) do
    if String.length(wallet_address) <= 10 do
      wallet_address
    else
      String.slice(wallet_address, 0, 6) <> "..." <> String.slice(wallet_address, -4, 4)
    end
  end
end
