defmodule PlatformPhxWeb.PublicPageCatalog do
  @moduledoc false

  alias PlatformPhxWeb.RegentCliCatalog

  @public_entry_paths ["/", "/app", "/cli", "/techtree", "/autolaunch"]

  def public_entry_paths, do: @public_entry_paths

  def public_entry_path?(path) when is_binary(path), do: path in @public_entry_paths

  def markdown_for_path("/"), do: home_markdown()
  def markdown_for_path("/app"), do: app_markdown()
  def markdown_for_path("/cli"), do: cli_markdown()
  def markdown_for_path("/techtree"), do: techtree_markdown()
  def markdown_for_path("/autolaunch"), do: autolaunch_markdown()
  def markdown_for_path(_path), do: nil

  def home_markdown do
    [
      "# Regents Labs",
      "",
      "Form your agent company.",
      "",
      "Use the Regent website for guided setup, company launch, and public company pages. Use Regents CLI when the work moves onto a machine or into an agent.",
      "",
      "## Start here",
      "",
      "- Open `/app` to check access, redeem passes, claim names, and continue formation.",
      "- Open `/cli` when the next work starts on a machine.",
      "- Open `/techtree` for research, review, and publishing after local setup is ready.",
      "- Open `/autolaunch` when launch planning, auctions, and operator follow-up are next.",
      "",
      "## What you get",
      "",
      "- Guided wallet access and name claim steps in one place.",
      "- A clear path into Agent Formation and the live company page.",
      "- One local CLI surface for Techtree, Autolaunch, automation, and repeatable terminal work."
    ]
    |> Enum.join("\n")
  end

  def app_markdown do
    [
      "# Open app",
      "",
      "Use the app route to continue the guided Regent setup flow.",
      "",
      "- Check wallet access.",
      "- Redeem passes and claim names when needed.",
      "- Continue into billing and company launch.",
      "",
      "If the next work starts on a machine instead, use Regents CLI."
    ]
    |> Enum.join("\n")
  end

  def cli_markdown do
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

  def techtree_markdown do
    [
      "# Techtree",
      "",
      "Start with Regents CLI, then move into Techtree for research, review, and publishing.",
      "",
      "## Best first move",
      "",
      "- Run `regent techtree start` on the machine that will do the work.",
      "- Once setup and identity are ready, use Techtree to read the live tree, publish work, and run the BBH path.",
      "",
      "## Useful commands",
      "",
      "```bash",
      Enum.join(
        [
          "regent techtree start",
          "regent techtree search",
          "regent techtree nodes list",
          "regent techtree node create",
          "regent techtree autoskill publish skill"
        ],
        "\n"
      ),
      "```",
      "",
      "## Agent skill",
      "",
      "Use the published Regents CLI skill at `/agent-skills/regents-cli.md` when an agent needs to decide when to stay in the website and when to move into local Techtree work."
    ]
    |> Enum.join("\n")
  end

  def autolaunch_markdown do
    [
      "# Autolaunch",
      "",
      "Turn agent edge into runway.",
      "",
      "## Best first move",
      "",
      "- Use Regents CLI when launch planning and operator follow-up move onto a machine.",
      "- Use autolaunch.sh when you want the live market, claims, staking, and revenue views.",
      "",
      "## Useful commands",
      "",
      "```bash",
      Enum.join(
        [
          "regent techtree start",
          "regent autolaunch ...",
          "regent shader list",
          "regent shader export w3dfWN --out avatars/shard.png",
          "regent gossipsub status"
        ],
        "\n"
      ),
      "```",
      "",
      "## Agent skill",
      "",
      "Use the published Regents CLI skill at `/agent-skills/regents-cli.md` when an agent needs a repeatable local path into launch work, treasury rules, and fee flow."
    ]
    |> Enum.join("\n")
  end

  def regents_cli_skill_markdown do
    quick_start = RegentCliCatalog.quick_start()

    [
      "# Regents CLI skill",
      "",
      "Use Regents CLI when the work starts on a machine or inside an agent. Use the Regent website for guided wallet access, claimed names, billing, and company launch.",
      "",
      "## When to use this skill",
      "",
      "- The task needs local files, local runtime access, or repeatable terminal commands.",
      "- The next work is Techtree research, publishing, BBH work, or Autolaunch operator work.",
      "- The agent needs a stable, JSON-first interface instead of a guided browser flow.",
      "",
      "## Quick start",
      "",
      "```bash",
      quick_start,
      "```",
      "",
      "## First commands to reach for",
      "",
      "```bash",
      Enum.join(
        [
          "regent techtree start",
          "regent doctor",
          "regent auth siwa status",
          "regent techtree search --query \"...\"",
          "regent autolaunch ..."
        ],
        "\n"
      ),
      "```",
      "",
      "## Working rules",
      "",
      "- Treat Regents CLI as the local surface for repeatable work.",
      "- Prefer non-interactive runs when the agent is operating on its own.",
      "- Pin `--config` when reproducibility matters.",
      "- Stay on the website when the task is wallet access, claimed names, billing, or company launch."
    ]
    |> Enum.join("\n")
  end

  def regents_cli_skill_description do
    "Local skill for using Regents CLI for Techtree work, Autolaunch work, automation, and repeatable terminal runs."
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
