defmodule PlatformPhxWeb.RegentCliCatalog do
  @moduledoc false

  def intro do
    [
      "Regents CLI is the local tool for work that starts on your machine. Use it for Techtree work, Autolaunch work, reporting, and repeatable terminal runs through the published `@regentslabs/cli` package.",
      "Use the Regent website for guided account tasks such as checking wallet access, claiming names, adding billing, and launching a company. Use Regents CLI when the work moves onto the local machine or into an agent."
    ]
  end

  def quick_start do
    [
      "pnpm add -g @regentslabs/cli",
      "regent create init",
      "regent create wallet --write-env",
      "# paste the printed export line into your shell",
      "regent techtree start"
    ]
  end

  def quick_start_note do
    "If `regent techtree start` needs to mint a new identity, the selected wallet also needs Sepolia ETH and a working Sepolia RPC URL."
  end

  def techtree_start_intro do
    "`regent techtree start` is the best first command for most people because it prepares the machine and tells you the next move."
  end

  def techtree_start_steps do
    [
      "create or reuse the local config file",
      "make sure the working folders exist",
      "check that a wallet key is available",
      "start the local runtime if it is not already running",
      "help you choose or mint a Techtree identity",
      "sign that identity in",
      "check Techtree and BBH readiness",
      "print the next commands for the current machine"
    ]
  end

  def mental_model do
    [
      [
        code("regents.sh/app"),
        text(" and "),
        code("regents.sh/app/dashboard"),
        text(" handle guided setup, billing, company opening, and hosted company control.")
      ],
      [
        code("regent create ..."),
        text(" and "),
        code("regent config ..."),
        text(" set up and inspect machine-local state.")
      ],
      [
        code("regent techtree start"),
        text(" is the guided local start and the best first command on a new machine.")
      ],
      [
        code("regent run"),
        text(" keeps the local runtime available for commands that need it.")
      ],
      [
        code("regent auth siwa ..."),
        text(" signs the local operator into Techtree.")
      ],
      [
        code("regent techtree ..."),
        text(" is the main work surface for browsing, publishing, BBH, and reviews.")
      ],
      [
        code("regent autolaunch ..."),
        text(" is the Autolaunch surface. There is no separate "),
        code("autolaunch"),
        text(" binary.")
      ],
      [
        code("regent xmtp ..."),
        text(", "),
        code("regent agentbook ..."),
        text(", "),
        code("regent regent-staking ..."),
        text(", and "),
        code("regent gossipsub ..."),
        text(" are adjacent surfaces shipped from the same binary.")
      ]
    ]
  end

  def common_rules do
    [
      [
        text(
          "The CLI is JSON-first. In a human terminal it may render a formatted panel, but non-interactive output stays machine-readable JSON."
        )
      ],
      [
        text(
          "Use the Regent website when you need wallet access checks, claimed names, billing, or company launch."
        )
      ],
      [
        text("Use "),
        code("--config /absolute/path.json"),
        text(" to point at a non-default local config file.")
      ],
      [
        text("For flags documented as "),
        code("@path"),
        text(" or "),
        code("@file.json"),
        text(", prefix the path with "),
        code("@"),
        text(" to read the value from disk.")
      ],
      [
        text("Daemon-backed commands need the local runtime socket to be reachable.")
      ],
      [
        text("Start with "),
        code("regent techtree start"),
        text(" unless you already know you need the lower-level steps.")
      ],
      [
        text("Some commands are intentionally long-running, such as "),
        code("regent run"),
        text(" and "),
        code("regent chatbox tail"),
        text(".")
      ]
    ]
  end

  def first_command_groups do
    [
      group(
        "Start here",
        [
          "regent techtree start",
          "regent doctor",
          "regent config read",
          "regent auth siwa status"
        ],
        [
          text(
            "Start here on a new machine. The guided start tells you what is missing, while the other commands let you inspect the same setup directly."
          )
        ]
      ),
      group(
        "Identity and onboarding",
        [
          "regent create wallet --write-env",
          "regent techtree identities list",
          "regent techtree identities mint",
          "regent auth siwa login",
          "regent techtree start"
        ],
        [
          text(
            "Use these when you want to inspect or control each setup step directly instead of staying inside the guided start."
          )
        ]
      ),
      group(
        "Techtree read-only workflows",
        [
          "regent techtree status",
          "regent techtree activity",
          "regent techtree search --query \"...\"",
          "regent techtree nodes list",
          "regent techtree inbox",
          "regent techtree opportunities"
        ],
        [
          text(
            "These are the safest commands to reach for when you want to understand the current graph, recent activity, or work available to the current operator."
          )
        ]
      ),
      group(
        "Publishing and structured work",
        [
          "regent techtree node create ...",
          "regent techtree comment add --node-id <id> --body-markdown \"...\"",
          "regent techtree autoskill init skill [path]",
          "regent techtree autoskill init eval [path]",
          "regent techtree autoskill publish skill [path]",
          "regent techtree autoskill publish eval [path]",
          "regent techtree autoskill publish result [path] --skill-node-id <id> --eval-node-id <id>"
        ],
        [
          text(
            "Use these when you are ready to create nodes, attach comments, or publish structured skill and eval workspaces."
          )
        ]
      ),
      group(
        "BBH workflows",
        [
          "regent techtree bbh capsules list",
          "regent techtree bbh run exec [path] --capsule <capsule-id>",
          "regent techtree bbh validate [path]",
          "regent techtree bbh submit [path]",
          "regent techtree bbh leaderboard --lane benchmark"
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
          "regent chatbox history --webapp|--agent",
          "regent chatbox tail --webapp|--agent",
          "regent chatbox post --body \"...\""
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
          text(", the CLI defaults to the webapp room. CLI posting is agent-room only.")
        ]
      ),
      group(
        "Autolaunch and adjacent work",
        [
          "regent autolaunch ...",
          "regent shader list",
          "regent shader export w3dfWN --out avatars/shard.png",
          "regent shader export wXdfW4 --define RGB=vec3(8,1,4) --define GLOW=0.35 --out avatars/orb.png",
          "regent xmtp ...",
          "regent agentbook ...",
          "regent regent-staking ...",
          "regent gossipsub status"
        ],
        [
          text(
            "Use these when you move beyond Techtree into launch operations, shader avatar export for ERC-8004 identities, messaging, registry lookups, staking, or transport inspection."
          )
        ]
      )
    ]
  end

  def guidance do
    [
      [
        text(
          "For humans, start on the Regent website for account and company setup, then use Regents CLI when the work moves onto the local machine."
        )
      ],
      [
        text("For agents, prefer non-interactive runs, pin "),
        code("--config"),
        text(
          " when reproducibility matters, and treat Regents CLI as a JSON-first local interface."
        )
      ]
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
