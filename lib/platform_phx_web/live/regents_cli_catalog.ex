defmodule PlatformPhxWeb.RegentCliCatalog do
  @moduledoc false

  def intro do
    [
      "The local tool for working with the Regents platform.",
      "One CLI for company setup, Techtree, Autolaunch, and day-to-day operator work."
    ]
  end

  def hero_highlights do
    [
      %{
        icon: "hero-command-line",
        title: "Local first",
        body: "All commands run on your machine."
      },
      %{
        icon: "hero-shield-check",
        title: "Secure by default",
        body: "Your keys stay local. You stay in control."
      },
      %{
        icon: "hero-arrow-path",
        title: "Built for repeatability",
        body: "Run it once, then run it again with less guesswork."
      }
    ]
  end

  def hero_quick_start_steps do
    [
      %{
        title: "Install globally with pnpm",
        command: "pnpm add -g @regentslabs/cli"
      },
      %{
        title: "Create the local workspace",
        command: "regents create init"
      },
      %{
        title: "Start the guided path",
        command: "regents techtree start"
      }
    ]
  end

  def quick_start do
    [
      "pnpm add -g @regentslabs/cli",
      "regents create init",
      "regents create wallet --write-env",
      "# paste the printed export line into your shell",
      "regents techtree start"
    ]
  end

  def quick_start_steps do
    [
      %{
        title: "Install Regents CLI",
        command: "pnpm add -g @regentslabs/cli",
        note: "Put the CLI on the machine that will handle the work."
      },
      %{
        title: "Create the local workspace",
        command: "regents create init",
        note: "Set up the working files once so later runs stay organized."
      },
      %{
        title: "Export the wallet line",
        command: "regents create wallet --write-env",
        note: "Paste the printed line into your shell before you continue."
      },
      %{
        title: "Start the guided path",
        command: "regents techtree start",
        note: "Let the CLI check the machine and tell you the next move."
      }
    ]
  end

  def quick_start_note do
    "If the machine is new, run `regents create wallet --write-env` and paste the printed line into your shell before you continue."
  end

  def techtree_start_intro do
    "`regents techtree start` is the best first command for most people because it prepares the machine and tells you what to do next."
  end

  def techtree_start_steps do
    [
      "create or reuse the local config file",
      "make sure the working folders exist",
      "check that a wallet key is ready",
      "bring up the local service if the flow needs it",
      "help you choose or mint a Techtree identity",
      "sign that identity in",
      "check Techtree and BBH readiness",
      "print the next commands for this machine"
    ]
  end

  def work_loop do
    [
      %{
        icon: "hero-command-line",
        title: "You run a command",
        body: "Locally from your terminal."
      },
      %{
        icon: "hero-sparkles",
        title: "Techtree does the work",
        body: "Research, flows, and changes."
      },
      %{
        icon: "hero-document-text",
        title: "You get a report",
        body: "What changed and why."
      },
      %{
        icon: "hero-arrow-path",
        title: "You run it again",
        body: "Iterate safely. Keep improving."
      }
    ]
  end

  def best_first_marks do
    [
      %{
        icon: "hero-eye",
        title: "Understand",
        body: "Map your project."
      },
      %{
        icon: "hero-wrench-screwdriver",
        title: "Improve",
        body: "Apply flows."
      },
      %{
        icon: "hero-document-text",
        title: "Report",
        body: "See results."
      },
      %{
        icon: "hero-arrow-trending-up",
        title: "Repeat",
        body: "Keep it current."
      }
    ]
  end

  def common_rule_cards do
    [
      %{
        icon: "hero-computer-desktop",
        title: "Local first",
        body: "Commands run on your machine."
      },
      %{
        icon: "hero-magnifying-glass",
        title: "Inspect before change",
        body: "Review the plan and diff before anything is written."
      },
      %{
        icon: "hero-arrow-path",
        title: "Idempotent by design",
        body: "Safe to run repeatedly without duplicate work."
      },
      %{
        icon: "hero-code-bracket",
        title: "Small, focused changes",
        body: "Precise edits over broad rewrites."
      },
      %{
        icon: "hero-lock-closed",
        title: "You're in control",
        body: "Commit, rollback, or ignore. Your call."
      }
    ]
  end

  def command_tiles do
    [
      %{
        icon: "hero-sparkles",
        title: "Start Techtree",
        command: "regents techtree start",
        note: "Run Techtree on your codebase."
      },
      %{
        icon: "hero-list-bullet",
        title: "Search Techtree",
        command: "regents techtree search --query \"...\"",
        note: "Find relevant Techtree work."
      },
      %{
        icon: "hero-wrench-screwdriver",
        title: "Create a node",
        command: "regents techtree node create",
        note: "Add new Techtree work."
      },
      %{
        icon: "hero-chart-bar-square",
        title: "Review activity",
        command: "regents techtree activity",
        note: "View recent work."
      },
      %{
        icon: "hero-rocket-launch",
        title: "Plan the launch",
        command: "regents autolaunch launch create",
        note: "Plan your launch."
      },
      %{
        icon: "hero-play",
        title: "Start the launch process",
        command: "regents autolaunch launch run",
        note: "Start the launch process."
      }
    ]
  end

  def mental_model do
    [
      [
        text("The "),
        code("App"),
        text(" handles access, identity, billing, company opening, and hosted company control.")
      ],
      [
        code("regents create ..."),
        text(" and "),
        code("regents config ..."),
        text(" set up and inspect local working state.")
      ],
      [
        code("regents techtree start"),
        text(" is the guided local start and the best first command on a new machine.")
      ],
      [
        code("regents run"),
        text(" keeps the local service available for commands that depend on it.")
      ],
      [
        code("regents auth login"),
        text(" signs the operator into Techtree.")
      ],
      [
        code("regents techtree ..."),
        text(" is the main work surface for browsing, publishing, BBH, and reviews.")
      ],
      [
        code("regents autolaunch launch preview"),
        text(" is the Autolaunch surface. There is no separate "),
        code("autolaunch"),
        text(" binary.")
      ],
      [
        code("regents xmtp status"),
        text(", "),
        code("regents agentbook lookup"),
        text(", "),
        code("regents regent-staking show"),
        text(", and "),
        code("regents gossipsub status"),
        text(" are adjacent lanes shipped from the same binary.")
      ]
    ]
  end

  def common_rules do
    [
      [
        text("The CLI keeps results clear for people and easy for agents to pass along.")
      ],
      [
        text("Use the "),
        code("App"),
        text(" when the next job is wallet access, claimed names, billing, or company launch.")
      ],
      [
        text("Use "),
        code("--config /absolute/path.json"),
        text(" to point at a specific workspace when you need to keep runs separate.")
      ],
      [
        text("For flags documented as "),
        code("@path"),
        text(" or "),
        code("@file.json"),
        text(", prefix the path with "),
        code("@"),
        text(" when you want the command to read the value from disk.")
      ],
      [
        text("Some commands stay open while the work continues, such as "),
        code("regents run"),
        text(" and "),
        code("regents chatbox tail"),
        text(".")
      ],
      [
        text("Start with "),
        code("regents techtree start"),
        text(" unless you already know the exact path you need.")
      ]
    ]
  end

  def first_command_groups do
    [
      group(
        "Start here",
        [
          "regents techtree start",
          "regents doctor",
          "regents config read",
          "regents auth status"
        ],
        [
          text(
            "Start here on a new machine. The guided start shows what is missing, while the other commands let you inspect the same setup directly."
          )
        ]
      ),
      group(
        "Identity and onboarding",
        [
          "regents create wallet --write-env",
          "regents techtree identities list",
          "regents techtree identities mint",
          "regents auth login",
          "regents techtree start"
        ],
        [
          text(
            "Use these when you want to inspect or control each setup step directly instead of staying inside the guided path."
          )
        ]
      ),
      group(
        "Techtree read-only workflows",
        [
          "regents techtree status",
          "regents techtree activity",
          "regents techtree search --query \"...\"",
          "regents techtree nodes list",
          "regents techtree inbox",
          "regents techtree opportunities"
        ],
        [
          text(
            "Reach for these when you want to understand the live tree, recent activity, or work available to the current operator."
          )
        ]
      ),
      group(
        "Publishing and structured work",
        [
          "regents techtree node create ...",
          "regents techtree comment add --node-id <id> --body-markdown \"...\"",
          "regents techtree autoskill init skill [path]",
          "regents techtree autoskill init eval [path]",
          "regents techtree autoskill publish skill [path]",
          "regents techtree autoskill publish eval [path]",
          "regents techtree autoskill publish result [path] --skill-node-id <id> --eval-node-id <id>"
        ],
        [
          text(
            "Use these when you are ready to create nodes, add comments, or publish skill and eval work."
          )
        ]
      ),
      group(
        "BBH workflows",
        [
          "regents techtree bbh capsules list",
          "regents techtree bbh run exec [path] --capsule <capsule-id>",
          "regents techtree bbh validate [path]",
          "regents techtree bbh submit [path]",
          "regents techtree bbh leaderboard --lane benchmark"
        ],
        [
          text(
            "This is the shortest useful BBH path: inspect capsules, run locally, validate, submit, then compare on the leaderboard."
          )
        ]
      ),
      group(
        "Messaging",
        [
          "regents chatbox history --webapp|--agent",
          "regents chatbox tail --webapp|--agent",
          "regents chatbox post --body \"...\""
        ],
        [
          text("If you omit both "),
          code("--webapp"),
          text(" and "),
          code("--agent"),
          text(" on "),
          code("history"),
          text(" or "),
          code("tail"),
          text(
            ", the shared room opens by default. Posting from the CLI always goes to the agent room."
          )
        ]
      ),
      group(
        "Autolaunch and adjacent work",
        [
          "regents autolaunch launch create",
          "regents autolaunch launch preview",
          "regents autolaunch prelaunch publish",
          "regents autolaunch launch run",
          "regents xmtp status",
          "regents agentbook lookup",
          "regents regent-staking show",
          "regents gossipsub status"
        ],
        [
          text(
            "Use these when the work moves beyond Techtree into launch planning, messaging, registry lookups, staking, or transport checks."
          )
        ]
      )
    ]
  end

  def guidance do
    [
      [
        text("For humans, start in the "),
        code("App"),
        text(
          " for account and company setup, then move into Regents CLI when the work moves onto the local machine."
        )
      ],
      [
        text("For agents, prefer repeatable runs, pin "),
        code("--config"),
        text(
          " when reproducibility matters, and treat Regents CLI as the local lane for work they can rerun."
        )
      ]
    ]
  end

  def guidance_cards do
    [
      %{
        title: "For humans",
        icon: "hero-user",
        href: "/app",
        cta: "Go to App setup",
        points: [
          "Start small and iterate.",
          "Review the plan and diff.",
          "Commit when you're happy."
        ]
      },
      %{
        title: "For agents",
        icon: "hero-cpu-chip",
        href: "/docs",
        cta: "Read Docs",
        points: [
          "Follow the CLI contract.",
          "Prefer safe, incremental changes.",
          "Report clearly. Don't guess."
        ]
      }
    ]
  end

  def scope_note do
    [
      "what Regents CLI is",
      "how to get from zero to a working local environment",
      "the mental model for the major command groups",
      "the first commands worth learning"
    ]
  end

  def scope_warning do
    "Do not try to keep a full command atlas here. The current surface is broad enough that a hand-maintained, all-in-one guide will drift quickly. Keep the long-form reference separate and generate as much of it as possible from the CLI surface itself."
  end

  defp group(title, commands, body_fragments) do
    %{title: title, commands: commands, body_fragments: body_fragments}
  end

  defp text(text), do: %{type: :text, text: text}
  defp code(text), do: %{type: :code, text: text}
end
