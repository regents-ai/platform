defmodule PlatformPhxWeb.PublicPageCatalog do
  @moduledoc false

  alias PlatformPhxWeb.RegentCliPage

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
      "Use the App for guided setup, company launch, and public company pages. Use Regents CLI when the work moves onto a machine or into an agent.",
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
      "- One local CLI surface for Techtree, Autolaunch, automation, and repeatable local work."
    ]
    |> Enum.join("\n")
  end

  def app_markdown do
    [
      "# App",
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

  def docs_markdown do
    [
      "# Docs",
      "",
      "Start here when you want the short version of where each Regent surface fits.",
      "",
      "## The path",
      "",
      "- Start in the App for access, identity, billing, and company opening.",
      "- Use the public company page after launch when you want the live company home.",
      "- Move into Regents CLI when the next step belongs on a machine.",
      "- Keep Techtree and Autolaunch as the two main work lanes after setup is ready.",
      "",
      "## What this page covers",
      "",
      "- The App for guided setup and company control.",
      "- The public company page after launch.",
      "- Regents CLI for local work that needs a machine.",
      "- Techtree and Autolaunch after setup is ready.",
      "",
      "## Quick links",
      "",
      "- `/app` for guided setup.",
      "- `/cli` for local work.",
      "- `/techtree` for research and publishing.",
      "- `/autolaunch` for launch planning and live market work.",
      "- `/bug-report` for the public bug report ledger."
    ]
    |> Enum.join("\n")
  end

  def cli_markdown do
    RegentCliPage.page_markdown()
  end

  def techtree_markdown do
    [
      "# Techtree",
      "",
      "Start with Regents CLI, then move into Techtree for research, review, and publishing.",
      "",
      "## Best first move",
      "",
      "- Run `regents techtree start` on the machine that will do the work.",
      "- Once setup and identity are ready, use Techtree to read the live tree, publish work, and run the BBH path.",
      "",
      "## Useful commands",
      "",
      "```bash",
      Enum.join(
        [
          "regents techtree start",
          "regents techtree search",
          "regents techtree nodes list",
          "regents techtree node create",
          "regents techtree autoskill publish skill"
        ],
        "\n"
      ),
      "```",
      "",
      "## Agent skill",
      "",
      "Use the published Regents CLI skill at `/agent-skills/regents-cli.md` when an agent needs to decide when to stay in the App and when to move into local Techtree work."
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
          "regents autolaunch plan",
          "regents autolaunch ...",
          "regents shader list",
          "regents shader export w3dfWN --out avatars/shard.png",
          "regents gossipsub status"
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
    quick_start = PlatformPhxWeb.RegentCliCatalog.quick_start()

    [
      "# Regents CLI skill",
      "",
      "Use Regents CLI when the work starts on a machine or inside an agent. Use the App for guided wallet access, claimed names, billing, and company launch.",
      "",
      "## When to use this skill",
      "",
      "- The task needs local files, local service access, or repeatable local commands.",
      "- The next work is Techtree research, publishing, BBH work, or Autolaunch operator work.",
      "- The agent needs a repeatable local path instead of a guided App flow.",
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
          "regents techtree start",
          "regents doctor",
          "regents auth siwa status",
          "regents techtree search --query \"...\"",
          "regents autolaunch ..."
        ],
        "\n"
      ),
      "```",
      "",
      "## Working rules",
      "",
      "- Treat Regents CLI as the local surface for repeatable work.",
      "- Prefer repeatable runs when the agent is operating on its own.",
      "- Pin `--config` when reproducibility matters.",
      "- Stay in the App when the task is wallet access, claimed names, billing, or company launch."
    ]
    |> Enum.join("\n")
  end

  def regents_cli_skill_description do
    "Local skill for using Regents CLI for Techtree work, Autolaunch work, automation, and repeatable local runs."
  end
end
