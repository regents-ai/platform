defmodule PlatformPhxWeb.RegentCliLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhxWeb.RegentCliCatalog

  @impl true
  def mount(_params, _session, socket) do
    intro = RegentCliCatalog.intro()
    quick_start = RegentCliCatalog.quick_start()
    quick_start_note = RegentCliCatalog.quick_start_note()
    techtree_start_intro = RegentCliCatalog.techtree_start_intro()
    techtree_start_steps = RegentCliCatalog.techtree_start_steps()
    mental_model = RegentCliCatalog.mental_model()
    common_rules = RegentCliCatalog.common_rules()
    first_command_groups = RegentCliCatalog.first_command_groups()
    guidance = RegentCliCatalog.guidance()

    {:ok,
     socket
     |> assign(:page_title, "Regents CLI")
     |> assign(:intro, intro)
     |> assign(:quick_start, quick_start)
     |> assign(:quick_start_note, quick_start_note)
     |> assign(:techtree_start_intro, techtree_start_intro)
     |> assign(:techtree_start_steps, techtree_start_steps)
     |> assign(:mental_model, mental_model)
     |> assign(:common_rules, common_rules)
     |> assign(:first_command_groups, first_command_groups)
     |> assign(:guidance, guidance)
     |> assign(
       :page_markdown,
       cli_markdown(%{
         intro: intro,
         quick_start: quick_start,
         quick_start_note: quick_start_note,
         techtree_start_intro: techtree_start_intro,
         techtree_start_steps: techtree_start_steps,
         mental_model: mental_model,
         common_rules: common_rules,
         first_command_groups: first_command_groups,
         guidance: guidance
       })
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
      active_nav="regents-cli"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-regents-cli-shell"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="BridgeReveal"
      >
        <div class="pp-route-stage">
          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-route-panel-span">
              <div class="pp-route-panel-heading">
                <div class="space-y-3">
                  <p class="pp-home-kicker">Regents CLI</p>
                  <h2 class="pp-route-panel-title">
                    Use Regents CLI when the work starts on your machine.
                  </h2>
                </div>
                <button
                  id="platform-regents-cli-markdown-copy"
                  type="button"
                  phx-hook="ClipboardCopy"
                  class="pp-copy-chip pp-copy-chip--wide"
                  aria-label="Copy Regents CLI page as markdown"
                  title="Copy Regents CLI page as markdown"
                  data-copy-text={@page_markdown}
                >
                  <span>Copy page as markdown</span>
                  <span class="pp-copy-chip-icon" aria-hidden="true">
                    <.icon name="hero-document-duplicate" class="size-4" />
                  </span>
                </button>
              </div>

              <%= for paragraph <- @intro do %>
                <p class="pp-panel-copy">{paragraph}</p>
              <% end %>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel">
              <p class="pp-home-kicker">Quick start</p>
              <h2 class="pp-route-panel-title">
                Install the package, set up local files, export the wallet, then start the guided Techtree path.
              </h2>
              <pre class="pp-product-cli-command">{Enum.join(@quick_start, "\n")}</pre>
              <p class="pp-panel-copy">{@quick_start_note}</p>
            </article>

            <article class="pp-route-panel">
              <p class="pp-home-kicker">Best first command</p>
              <h2 class="pp-route-panel-title">
                Start with <code>regent techtree start</code>
              </h2>
              <p class="pp-panel-copy">{@techtree_start_intro}</p>
              <ul class="pp-fact-list">
                <%= for step <- @techtree_start_steps do %>
                  <li>{step}</li>
                <% end %>
              </ul>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel">
              <p class="pp-home-kicker">Mental model</p>
              <h2 class="pp-route-panel-title">
                The CLI handles local work. The website handles guided account and company setup.
              </h2>
              <ul class="pp-fact-list">
                <%= for item <- @mental_model do %>
                  <li>
                    <.rich_fragments fragments={item} />
                  </li>
                <% end %>
              </ul>
            </article>

            <article class="pp-route-panel">
              <p class="pp-home-kicker">Common rules</p>
              <h2 class="pp-route-panel-title">
                Keep local files explicit and treat command output as data first.
              </h2>
              <ul class="pp-fact-list">
                <%= for rule <- @common_rules do %>
                  <li><.rich_fragments fragments={rule} /></li>
                <% end %>
              </ul>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel pp-route-panel-span">
              <p class="pp-home-kicker">First commands to know</p>
              <h2 class="pp-route-panel-title">
                Learn the next commands by task instead of trying to memorize the whole tool.
              </h2>
              <div class="pp-product-cli-grid pp-product-cli-grid--two-up">
                <%= for group <- @first_command_groups do %>
                  <section class="pp-product-cli-card">
                    <p class="pp-home-kicker">{group.title}</p>
                    <pre class="pp-product-cli-command">{Enum.join(group.commands, "\n")}</pre>
                    <p class="pp-panel-copy"><.rich_fragments fragments={group.body_fragments} /></p>
                  </section>
                <% end %>
              </div>
            </article>
          </section>

          <section class="pp-route-grid" data-bridge-block>
            <article class="pp-route-panel">
              <p class="pp-home-kicker">Guidance for humans and agents</p>
              <h2 class="pp-route-panel-title">
                Use the website for guided setup. Use the CLI for local work and repeatable runs.
              </h2>
              <ul class="pp-fact-list">
                <%= for item <- @guidance do %>
                  <li><.rich_fragments fragments={item} /></li>
                <% end %>
              </ul>
            </article>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp cli_markdown(%{
         intro: intro,
         quick_start: quick_start,
         quick_start_note: quick_start_note,
         techtree_start_intro: techtree_start_intro,
         techtree_start_steps: techtree_start_steps,
         mental_model: mental_model,
         common_rules: common_rules,
         first_command_groups: first_command_groups,
         guidance: guidance
       }) do
    [
      "# Regents CLI",
      "",
      intro,
      "",
      "## Quick start",
      "",
      "```bash",
      quick_start,
      "```",
      "",
      quick_start_note,
      "",
      "## Start with `regent techtree start`",
      "",
      techtree_start_intro,
      ""
    ]
    |> Kernel.++(Enum.map(techtree_start_steps, &"- #{&1}"))
    |> Kernel.++([
      "",
      "## Mental model",
      "",
      "The CLI handles local work. The Regent website handles guided account and company setup.",
      ""
    ])
    |> Kernel.++(
      Enum.map(mental_model, fn fragments ->
        "- #{fragments_to_markdown(fragments)}"
      end)
    )
    |> Kernel.++([
      "",
      "## Common rules",
      ""
    ])
    |> Kernel.++(Enum.map(common_rules, &"- #{fragments_to_markdown(&1)}"))
    |> Kernel.++([
      "",
      "## First commands to know",
      ""
    ])
    |> Kernel.++(
      Enum.flat_map(first_command_groups, fn group ->
        [
          "### #{group.title}",
          "",
          "```bash",
          Enum.join(group.commands, "\n"),
          "```",
          "",
          fragments_to_markdown(group.body_fragments),
          ""
        ]
      end)
    )
    |> Kernel.++([
      "## Guidance for humans and agents",
      ""
    ])
    |> Kernel.++(Enum.map(guidance, &"- #{fragments_to_markdown(&1)}"))
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp fragments_to_markdown(fragments) when is_list(fragments) do
    fragments
    |> Enum.map(fn fragment ->
      case fragment.type do
        :text -> fragment.text
        :code -> "`#{fragment.text}`"
        :highlight -> fragment.text
        :link -> "[#{fragment.label}](#{fragment.href})"
      end
    end)
    |> Enum.join()
  end
end
