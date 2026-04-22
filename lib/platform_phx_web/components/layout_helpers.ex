defmodule PlatformPhxWeb.LayoutHelpers do
  @nav_items [
    %{
      kind: :internal,
      key: "regents",
      href: "/",
      label: "Regents",
      note: "Setup",
      icon: "hero-sparkles"
    },
    %{
      kind: :internal,
      key: "techtree",
      href: "/techtree",
      label: "Techtree",
      note: "Research",
      icon: "hero-beaker"
    },
    %{
      kind: :internal,
      key: "autolaunch",
      href: "/autolaunch",
      label: "Autolaunch",
      note: "Funding",
      icon: "hero-rocket-launch"
    },
    %{
      kind: :internal,
      key: "cli",
      href: "/cli",
      label: "CLI",
      note: "Machine work",
      icon: "hero-command-line"
    },
    %{
      kind: :internal,
      key: "docs",
      href: "/docs",
      label: "Docs",
      note: "Reference",
      icon: "hero-book-open"
    }
  ]

  @quick_search_items [
    %{label: "App setup", href: "/app"},
    %{label: "Check access", href: "/app/access"},
    %{label: "Claim identity", href: "/app/identity"},
    %{label: "Add billing", href: "/app/billing"},
    %{label: "Open company", href: "/app/formation"},
    %{label: "Company opening", href: "/app/formation"},
    %{label: "Company dashboard", href: "/app/dashboard"},
    %{label: "Human-backed trust", href: "/app/trust"},
    %{label: "Techtree", href: "/techtree"},
    %{label: "Autolaunch", href: "/autolaunch"},
    %{label: "Regents CLI", href: "/cli"},
    %{label: "Docs", href: "/docs"},
    %{label: "Token info", href: "/token-info"},
    %{label: "Bug report", href: "/bug-report"}
  ]

  @chrome_eyebrows %{
    "regents" => "App setup",
    "bug-report" => "Public operator ledger",
    "techtree" => "Shared research and eval tree",
    "autolaunch" => "Raise agent capital",
    "cli" => "Local operator surface",
    "docs" => "Docs",
    "token-info" => "Platform revenue token",
    "shader" => "Shader registry"
  }

  @nav_titles Map.new(@nav_items, &{&1.key, &1.label})

  def nav_items, do: @nav_items

  def quick_search_items, do: @quick_search_items

  def header_eyebrow(nil, active_nav), do: Map.get(@chrome_eyebrows, active_nav, "Regents Labs")
  def header_eyebrow(value, _active_nav), do: value

  def shell_title(nil, active_nav), do: Map.get(@nav_titles, active_nav, "Regents")
  def shell_title(value, _active_nav), do: value

  def continue_label(current_human) do
    if current_human, do: "Continue setup", else: "App setup"
  end
end
