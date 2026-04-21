defmodule PlatformPhxWeb.AutolaunchLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentLaunch
  alias PlatformPhxWeb.RegentScenes

  @default_focus "launch"

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    auctions = AgentLaunch.list_auctions()
    split = AgentLaunch.split_auctions(auctions)
    current_count = length(split.current)
    past_count = length(split.past)

    {:ok,
     socket
     |> assign(:page_title, "Autolaunch")
     |> assign(:bridge_focus, @default_focus)
     |> assign(:current_auctions, split.current)
     |> assign(:past_auctions, split.past)
     |> assign(:current_count, current_count)
     |> assign(:past_count, past_count)
     |> assign_regent_scene()}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("regent:node_select", %{"meta" => %{"focus" => focus}}, socket) do
    {:noreply,
     socket
     |> assign(:bridge_focus, RegentScenes.autolaunch_focus(focus))
     |> assign_regent_scene()}
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
       "The Autolaunch bridge surface could not render in this browser session."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="autolaunch"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-autolaunch-shell"
        class="pp-route-shell rg-regent-theme-autolaunch"
        phx-hook="AutolaunchReveal"
      >
        <div class="pp-route-stage">
          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-product-panel pp-product-panel--feature">
              <p class="pp-home-kicker">Purpose</p>
              <h2 class="pp-route-panel-title">
                Turn agent edge into runway.
              </h2>
              <p class="pp-panel-copy">
                Launch a market around a real agent and bring in aligned backers before compute and
                API bills set the pace.
              </p>
              <p class="pp-panel-copy">
                Buyers bring a budget and a price cap, so the sale rewards conviction more than
                click speed.
              </p>
              <p class="pp-panel-copy">
                After the sale, the same product keeps claims, staking, and revenue in one place.
              </p>
              <p class="pp-panel-copy">
                The goal is simple: give a strong agent the capital and staying power to keep
                improving.
              </p>
            </article>

            <article class="pp-route-panel pp-product-panel">
              <p class="pp-home-kicker">Tech stack</p>
              <h2 class="pp-route-panel-title">
                Linked tools, runtimes, agent surfaces, and platforms behind Autolaunch.
              </h2>
              <div class="pp-product-stack-grid">
                <%= for section <- autolaunch_stack_sections() do %>
                  <section class="pp-product-stack-card">
                    <p class="pp-home-kicker">{section.title}</p>
                    <ul class="pp-product-link-list">
                      <%= for item <- section.items do %>
                        <li>
                          <a
                            href={item.href}
                            target="_blank"
                            rel="noreferrer"
                            class="pp-preview-link-list"
                          >
                            {item.label}
                          </a>
                        </li>
                      <% end %>
                    </ul>
                  </section>
                <% end %>
              </div>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-product-panel">
              <p class="pp-home-kicker">Agent Skill</p>
              <h2 class="pp-route-panel-title">
                Give the agent the launch playbook before capital is at risk.
              </h2>
              <p class="pp-panel-copy">
                The skill explains when to stay in the website, when to move into the CLI, and how
                treasury, fees, and long-term revenue fit together.
              </p>
              <div class="pp-link-row">
                <a
                  href={~p"/agent-skills/regents-cli.md"}
                  class="pp-link-button pp-link-button-slim"
                >
                  Open Regents CLI skill <span aria-hidden="true">↗</span>
                </a>
              </div>
            </article>

            <article class="pp-route-panel pp-product-panel">
              <p class="pp-home-kicker">Preview</p>
              <h2 class="pp-route-panel-title">
                Open the live market, or inspect the repo behind it.
              </h2>
              <p class="pp-panel-copy">
                Autolaunch is live at autolaunch.sh. The repo is where the operator docs, contract
                rules, and launch flow live in full.
              </p>
              <div class="pp-link-row">
                <.preview_link variant="pill" href="https://autolaunch.sh">
                  Open autolaunch.sh <span aria-hidden="true">↗</span>
                </.preview_link>
                <a
                  href="https://github.com/regents-ai/autolaunch"
                  target="_blank"
                  rel="noreferrer"
                  class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                >
                  Browse GitHub repo <span aria-hidden="true">↗</span>
                </a>
              </div>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-product-panel pp-route-panel-span">
              <p class="pp-home-kicker">CLI rails</p>
              <h2 class="pp-route-panel-title">
                The short path for operators and agents.
              </h2>
              <div class="pp-product-cli-grid pp-product-cli-grid--two-up">
                <%= for command <- autolaunch_cli_examples() do %>
                  <section class="pp-product-cli-card">
                    <code class="pp-product-cli-command">{command.command}</code>
                    <p class="pp-panel-copy">{command.description}</p>
                  </section>
                <% end %>
              </div>
            </article>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp assign_regent_scene(socket) do
    focus = RegentScenes.autolaunch_focus(socket.assigns[:bridge_focus] || @default_focus)
    next_version = (socket.assigns[:regent_scene_version] || 0) + 1
    current_count = socket.assigns.current_count
    past_count = socket.assigns.past_count

    socket
    |> assign(:bridge_focus, focus)
    |> assign(:bridge_content, RegentScenes.autolaunch_content(focus, current_count, past_count))
    |> assign(:regent_selected_target_id, "autolaunch:#{focus}")
    |> assign(:regent_scene_version, next_version)
    |> assign(
      :regent_scene,
      RegentScenes.autolaunch_bridge(current_count, past_count, focus, next_version)
    )
  end

  defp autolaunch_stack_sections do
    [
      %{
        title: "Agent stack",
        items: [
          %{label: "Openclaw", href: "https://openclaw.sh"},
          %{label: "Hermes", href: "https://hermes.ac"},
          %{label: "ENSIP-25", href: "https://ens.domains/blog/post/ensip-25"},
          %{label: "ERC-8004", href: "https://8004scan.io/"},
          %{label: "x402", href: "https://www.x402.org/"},
          %{label: "MPP", href: "https://stripe.com/blog/machine-payments-protocol"}
        ]
      },
      %{
        title: "Backend",
        items: [
          %{label: "Elixir", href: "https://elixir-lang.org"},
          %{label: "Ecto", href: "https://hexdocs.pm/ecto/Ecto.html"},
          %{label: "Dragonfly", href: "https://www.dragonflydb.io/"},
          %{label: "Privy", href: "https://privy.io"},
          %{label: "IPFS", href: "https://ipfs.io"},
          %{label: "Ethereum", href: "https://ethereum.org"},
          %{label: "Base", href: "https://base.org"}
        ]
      },
      %{
        title: "Frontend",
        items: [
          %{label: "Phoenix Framework", href: "https://www.phoenixframework.org"},
          %{label: "Phoenix LiveView", href: "https://hexdocs.pm/phoenix_live_view/welcome.html"},
          %{label: "TypeScript", href: "https://www.typescriptlang.org"},
          %{label: "Heerich", href: "https://www.npmjs.com/package/heerich"},
          %{label: "IDKit", href: "https://docs.world.org/world-id/id/web-react"}
        ]
      }
    ]
  end

  defp autolaunch_cli_examples do
    [
      %{
        command: "regent autolaunch prelaunch wizard",
        description: "Shape the raise before anything goes live."
      },
      %{
        command: "regent autolaunch prelaunch publish",
        description: "Publish the launch brief and sale assets."
      },
      %{
        command: "regent autolaunch launch run",
        description: "Start the raise from the saved plan."
      },
      %{
        command: "regent autolaunch launch monitor",
        description: "Track what needs attention while the sale is live."
      },
      %{
        command: "regent autolaunch launch finalize",
        description: "Settle the launch and move into the market."
      },
      %{
        command: "regent autolaunch auctions list",
        description: "See what people can back right now."
      },
      %{
        command: "regent autolaunch bids quote",
        description: "Check the numbers before committing funds."
      },
      %{
        command: "regent autolaunch bids place",
        description: "Back an agent from the market rail."
      },
      %{
        command: "regent autolaunch positions list",
        description: "Track what can be claimed, exited, or returned."
      },
      %{
        command: "regent autolaunch trust x-link --agent <id>",
        description: "Add public proof around the agent when it matters."
      }
    ]
  end
end
