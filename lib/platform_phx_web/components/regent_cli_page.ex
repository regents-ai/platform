defmodule PlatformPhxWeb.RegentCliPage do
  use PlatformPhxWeb, :html

  alias PlatformPhxWeb.RegentCliCatalog

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_human, :map, default: nil
  attr :intro, :list, required: true
  attr :hero_highlights, :list, required: true
  attr :hero_quick_start_steps, :list, required: true
  attr :quick_start_note, :string, required: true
  attr :techtree_start_intro, :string, required: true
  attr :best_first_marks, :list, required: true
  attr :work_loop, :list, required: true
  attr :common_rule_cards, :list, required: true
  attr :command_tiles, :list, required: true
  attr :guidance_cards, :list, required: true
  attr :page_markdown, :string, required: true

  def page(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_human={@current_human}
      chrome={:app}
      active_nav="cli"
      header_eyebrow="CLI"
      header_title="Regents CLI"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-regents-cli-shell"
        class="rg-regent-theme-platform space-y-6"
        phx-hook="BridgeReveal"
      >
        <section
          id="platform-regents-cli-hero"
          data-bridge-block
          class="overflow-hidden rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)]"
        >
          <div class="grid gap-0 xl:grid-cols-[minmax(0,1.03fr)_minmax(24rem,0.97fr)]">
            <div class="space-y-8 px-6 py-7 sm:px-8 sm:py-9">
              <div class="space-y-5">
                <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
                  Command the stack
                </p>
                <div class="space-y-4">
                  <h2 class="font-display text-[clamp(3.2rem,7vw,5.9rem)] leading-[0.88] tracking-[-0.075em] text-[color:var(--foreground)]">
                    Regents CLI
                  </h2>
                  <div class="max-w-[38rem] space-y-2 text-[1.18rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_76%,var(--muted-foreground)_24%)]">
                    <%= for paragraph <- @intro do %>
                      <p>{paragraph}</p>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="grid gap-4 md:grid-cols-3">
                <%= for highlight <- @hero_highlights do %>
                  <section class="rounded-[1.4rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 py-4">
                    <div class="flex items-start gap-3">
                      <div class="flex size-11 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                        <.icon name={highlight.icon} class="size-5" />
                      </div>
                      <div class="space-y-1">
                        <p class="text-sm font-medium text-[color:var(--foreground)]">
                          {highlight.title}
                        </p>
                        <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                          {highlight.body}
                        </p>
                      </div>
                    </div>
                  </section>
                <% end %>
              </div>
            </div>

            <section
              id="platform-regents-cli-quick-start"
              class="relative border-t border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-7 sm:px-8 sm:py-9 xl:border-l xl:border-t-0"
            >
              <div class="grid gap-8 xl:grid-cols-[minmax(0,1fr)_14rem]">
                <div class="space-y-5">
                  <div class="flex items-start justify-between gap-4">
                    <div class="space-y-2">
                      <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:color-mix(in_oklch,var(--foreground)_54%,var(--muted-foreground)_46%)]">
                        Try it locally
                      </p>
                      <h3 class="font-display text-[2.15rem] leading-none tracking-[-0.06em] text-[color:var(--foreground)]">
                        Quick start
                      </h3>
                    </div>

                    <button
                      id="platform-regents-cli-markdown-copy"
                      type="button"
                      phx-hook="ClipboardCopy"
                      class="pp-copy-chip pp-copy-chip--prompt inline-flex h-10 items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                      aria-label="Copy Regents CLI page as markdown"
                      title="Copy Regents CLI page as markdown"
                      data-copy-text={@page_markdown}
                    >
                      <span>Copy page as markdown</span>
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  </div>

                  <ol class="space-y-3">
                    <%= for {step, index} <- Enum.with_index(@hero_quick_start_steps, 1) do %>
                      <li class="grid grid-cols-[1.6rem_minmax(0,1fr)] gap-3">
                        <div class="mt-2 flex h-6 w-6 items-center justify-center rounded-full bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] text-[0.72rem] font-medium text-[color:var(--brand-ink)]">
                          {index}
                        </div>
                        <div class="space-y-2">
                          <p class="text-sm text-[color:var(--foreground)]">{step.title}</p>
                          <div class="flex items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-3">
                            <code class="min-w-0 flex-1 truncate text-[0.98rem] text-[color:var(--foreground)]">
                              {step.command}
                            </code>
                            <button
                              id={"platform-regents-cli-quick-start-copy-#{index}"}
                              type="button"
                              phx-hook="ClipboardCopy"
                              class="pp-copy-chip inline-flex h-8 w-8 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                              aria-label={"Copy quick start command #{index}"}
                              title={"Copy quick start command #{index}"}
                              data-copy-text={step.command}
                            >
                              <.icon name="hero-document-duplicate" class="size-4" />
                            </button>
                          </div>
                        </div>
                      </li>
                    <% end %>
                  </ol>

                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                    {@quick_start_note}
                  </p>
                </div>

                <div class="relative flex items-center justify-center lg:mt-1" aria-hidden="true">
                  <div class="absolute inset-auto h-36 w-36 rounded-[2.2rem] border border-dashed border-[color:color-mix(in_oklch,var(--brand-ink)_20%,transparent)] sm:h-40 sm:w-40 xl:h-44 xl:w-44 [transform:rotate(45deg)]">
                  </div>
                  <div class="absolute h-24 w-24 rounded-[1.55rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--background)_96%,var(--card)_4%),color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%))] shadow-[0_26px_52px_-34px_color-mix(in_oklch,var(--foreground)_22%,transparent)] sm:h-[6.5rem] sm:w-[6.5rem] xl:h-28 xl:w-28 [transform:rotate(45deg)]">
                  </div>
                  <div class="relative flex h-20 w-20 items-center justify-center rounded-[1.35rem] bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_78%,white_22%),color-mix(in_oklch,var(--brand-ink)_92%,black_8%))] text-white shadow-[0_26px_52px_-30px_color-mix(in_oklch,var(--brand-ink)_72%,transparent)] sm:h-24 sm:w-24 xl:h-24 xl:w-24">
                    <.icon name="hero-command-line" class="size-8 sm:size-10" />
                  </div>
                </div>
              </div>
            </section>
          </div>
        </section>

        <div class="grid gap-6 xl:grid-cols-[minmax(0,0.95fr)_minmax(0,1.65fr)]" data-bridge-block>
          <article
            id="platform-regents-cli-best-first-command"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6 sm:px-7"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Best first command
            </p>
            <div class="mt-4 flex items-center gap-3 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-4">
              <code class="min-w-0 flex-1 text-[1.04rem] text-[color:var(--foreground)] sm:text-[1.15rem]">
                regents techtree start
              </code>
              <button
                id="platform-regents-cli-best-first-copy"
                type="button"
                phx-hook="ClipboardCopy"
                class="inline-flex h-9 w-9 items-center justify-center rounded-[0.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                aria-label="Copy the best first command"
                title="Copy the best first command"
                data-copy-text="regents techtree start"
              >
                <.icon name="hero-document-duplicate" class="size-4" />
              </button>
            </div>
            <p class="mt-4 max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
              {@techtree_start_intro}
            </p>

            <div class="mt-5 grid gap-3 sm:grid-cols-2">
              <%= for mark <- @best_first_marks do %>
                <section class="rounded-[1.15rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_88%,var(--card)_12%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <div class="flex size-9 shrink-0 items-center justify-center rounded-[0.85rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_8%,var(--background)_92%)] text-[color:var(--brand-ink)]">
                      <.icon name={mark.icon} class="size-4" />
                    </div>
                    <div class="space-y-1">
                      <p class="text-sm font-medium text-[color:var(--foreground)]">{mark.title}</p>
                      <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                        {mark.body}
                      </p>
                    </div>
                  </div>
                </section>
              <% end %>
            </div>
          </article>

          <article
            id="platform-regents-cli-work-loop"
            class="rounded-[1.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6 sm:px-7"
          >
            <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
              Mental model
            </p>
            <div class="mt-5 grid gap-3 xl:grid-cols-[repeat(4,minmax(0,1fr))]">
              <%= for {loop, index} <- Enum.with_index(@work_loop) do %>
                <div class="flex items-center gap-3">
                  <section class="min-h-[7.75rem] flex-1 rounded-[1.2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_90%,var(--card)_10%)] px-4 py-5 text-center">
                    <div class="mx-auto flex size-11 items-center justify-center rounded-full bg-[linear-gradient(180deg,color-mix(in_oklch,var(--brand-ink)_80%,white_20%),color-mix(in_oklch,var(--brand-ink)_92%,black_8%))] text-white">
                      <.icon name={loop.icon} class="size-5" />
                    </div>
                    <p class="mt-4 text-sm font-medium text-[color:var(--foreground)]">
                      {loop.title}
                    </p>
                    <p class="mt-2 text-xs leading-5 text-[color:var(--muted-foreground)]">
                      {loop.body}
                    </p>
                  </section>
                  <div
                    :if={index < length(@work_loop) - 1}
                    class="hidden h-px flex-1 bg-[color:color-mix(in_oklch,var(--border)_70%,transparent)] xl:block"
                  >
                  </div>
                </div>
              <% end %>
            </div>
          </article>
        </div>

        <section class="grid gap-4 lg:grid-cols-2" data-bridge-block>
          <%= for card <- @common_rule_cards do %>
            <article class="rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-5 py-5">
              <div class="flex items-start gap-4">
                <div class="flex size-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                  <.icon name={card.icon} class="size-6" />
                </div>
                <div class="space-y-2">
                  <h3 class="text-[1.05rem] font-medium text-[color:var(--foreground)]">
                    {card.title}
                  </h3>
                  <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">{card.body}</p>
                </div>
              </div>
            </article>
          <% end %>
        </section>

        <section
          id="platform-regents-cli-commands"
          class="grid gap-4 xl:grid-cols-3"
          data-bridge-block
        >
          <%= for {tile, index} <- Enum.with_index(@command_tiles, 1) do %>
            <article class="rounded-[1.5rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-5 py-5">
              <div class="flex items-start justify-between gap-3">
                <div class="space-y-1">
                  <p class="text-xs uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                    {tile.note}
                  </p>
                  <p class="font-medium text-[color:var(--foreground)]">{tile.title}</p>
                </div>
                <button
                  id={"platform-regents-cli-command-copy-#{index}"}
                  type="button"
                  phx-hook="ClipboardCopy"
                  class="pp-copy-chip inline-flex h-8 w-8 items-center justify-center rounded-[0.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                  aria-label={"Copy #{tile.title} command"}
                  title={"Copy #{tile.title} command"}
                  data-copy-text={tile.command}
                >
                  <.icon name="hero-document-duplicate" class="size-4" />
                </button>
              </div>
              <code class="mt-3 block rounded-[0.9rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-3 py-2 text-sm text-[color:var(--foreground)]">
                {tile.command}
              </code>
            </article>
          <% end %>
        </section>

        <section
          id="platform-regents-cli-guidance"
          class="grid gap-4 lg:grid-cols-2"
          data-bridge-block
        >
          <%= for card <- @guidance_cards do %>
            <article class="rounded-[1.6rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-5 py-5">
              <div class="flex items-start gap-4">
                <div class="flex size-12 shrink-0 items-center justify-center rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] text-[color:var(--brand-ink)]">
                  <.icon name={card.icon} class="size-6" />
                </div>
                <div class="space-y-3">
                  <h3 class="text-[1.05rem] font-medium text-[color:var(--foreground)]">
                    {card.title}
                  </h3>
                  <div class="flex flex-wrap gap-2">
                    <%= for point <- card.points do %>
                      <span class="rounded-full border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-3 py-1 text-xs text-[color:var(--muted-foreground)]">
                        {point}
                      </span>
                    <% end %>
                  </div>
                  <.link
                    navigate={card.href}
                    class="inline-flex items-center gap-2 text-sm text-[color:var(--brand-ink)]"
                  >
                    {card.cta} <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </div>
            </article>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  def page_markdown do
    intro = RegentCliCatalog.intro()
    quick_start = RegentCliCatalog.quick_start()
    quick_start_note = RegentCliCatalog.quick_start_note()
    techtree_start_intro = RegentCliCatalog.techtree_start_intro()
    techtree_start_steps = RegentCliCatalog.techtree_start_steps()
    mental_model = RegentCliCatalog.mental_model()
    common_rules = RegentCliCatalog.common_rules()
    first_command_groups = RegentCliCatalog.first_command_groups()
    guidance = RegentCliCatalog.guidance()

    [
      "# Regents CLI",
      "",
      Enum.join(intro, "\n"),
      "",
      "## Quick start",
      "",
      "```bash",
      Enum.join(quick_start, "\n"),
      "```",
      "",
      quick_start_note,
      "",
      "## Best first command",
      "",
      "Start with `regents techtree start`.",
      "",
      techtree_start_intro,
      ""
    ]
    |> Kernel.++(Enum.map(techtree_start_steps, &"- #{&1}"))
    |> Kernel.++([
      "",
      "## Mental model",
      "",
      "Keep the local path simple: run a command, let the work happen, review the result, then run it again.",
      ""
    ])
    |> Kernel.++(Enum.map(mental_model, &"- #{fragments_to_markdown(&1)}"))
    |> Kernel.++(["", "## Common rules", ""])
    |> Kernel.++(Enum.map(common_rules, &"- #{fragments_to_markdown(&1)}"))
    |> Kernel.++(["", "## First commands to know", ""])
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
    |> Kernel.++(["## Guidance for humans and agents", ""])
    |> Kernel.++(Enum.map(guidance, &"- #{fragments_to_markdown(&1)}"))
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp fragments_to_markdown(fragments) do
    fragments
    |> Enum.map(fn
      %{type: :code, text: text} -> "`#{text}`"
      %{type: :text, text: text} -> text
      text when is_binary(text) -> text
    end)
    |> Enum.join("")
  end
end
