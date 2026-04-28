defmodule PlatformPhxWeb.AppComponents.SetupPresenter do
  @moduledoc false

  def setup_snapshot_from_services(services) do
    %{
      wallet_connected?: Map.get(services, :authenticated, false) == true,
      pass_ready?: eligible_services?(services),
      claimable_names: available_claim_count(services),
      billing_status: :not_started,
      company_opened?: false,
      company_opening?: false
    }
  end

  def setup_snapshot_from_formation(nil), do: empty_setup_snapshot()

  def setup_snapshot_from_formation(formation) do
    %{
      wallet_connected?: Map.get(formation, :authenticated, false) == true,
      pass_ready?:
        Map.get(formation, :eligible, false) == true or total_eligible_tokens(formation) > 0,
      claimable_names: available_claim_count(formation),
      billing_status: setup_billing_status(Map.get(formation, :billing_account)),
      company_opened?: owned_company_count(formation) > 0,
      company_opening?: active_formation?(formation)
    }
  end

  def setup_snapshot_from_company(company, formation) do
    formation_snapshot =
      setup_snapshot_from_formation(%{
        authenticated: true,
        eligible: true,
        available_claims: [],
        billing_account: %{connected: true},
        owned_companies: if(company, do: [company], else: []),
        active_formations: if(formation, do: [formation], else: [])
      })

    %{
      formation_snapshot
      | company_opened?: not is_nil(company) and not formation_active?(formation),
        company_opening?: formation_active?(formation)
    }
  end

  def setup_step_items(snapshot, current_step) do
    [
      %{number: 1, title: "Check access", copy: "Wallet and pass status", path: "/app/access"},
      %{
        number: 2,
        title: "Claim identity",
        copy: "Choose your company name",
        path: "/app/identity"
      },
      %{number: 3, title: "Add billing", copy: "Activate payments", path: "/app/billing"},
      %{number: 4, title: "Open company", copy: "Launch your company", path: "/app/formation"}
    ]
    |> Enum.map(fn item ->
      Map.put(item, :state, setup_step_state(item.number, snapshot, current_step))
    end)
  end

  def setup_completed_steps(snapshot) do
    [
      snapshot.wallet_connected? and snapshot.pass_ready?,
      snapshot.claimable_names > 0,
      snapshot.billing_status == :connected,
      snapshot.company_opened?
    ]
    |> Enum.count(& &1)
  end

  def setup_progress_percent(snapshot), do: round(setup_completed_steps(snapshot) / 4 * 100)

  def setup_step_circle_class(:complete),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] text-[color:var(--positive)]"

  def setup_step_circle_class(:current),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--ring)] bg-[color:color-mix(in_oklch,var(--ring)_10%,transparent)] text-[color:var(--brand-ink)]"

  def setup_step_circle_class(:upcoming),
    do:
      "flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--border)] bg-[color:var(--background)] text-[color:var(--muted-foreground)]"

  def setup_step_title_class(:complete), do: "text-sm text-[color:var(--foreground)]"
  def setup_step_title_class(:current), do: "text-sm text-[color:var(--brand-ink)]"
  def setup_step_title_class(:upcoming), do: "text-sm text-[color:var(--foreground)]"

  def setup_status_cards(snapshot) do
    [
      %{
        label: "Wallet",
        copy: if(snapshot.wallet_connected?, do: "Ready for setup", else: "Sign in to continue"),
        state: if(snapshot.wallet_connected?, do: "Connected", else: "Action needed"),
        tone: if(snapshot.wallet_connected?, do: :success, else: :warning)
      },
      %{
        label: "Pass access",
        copy:
          if(snapshot.pass_ready?, do: "This wallet qualifies", else: "Qualifying pass required"),
        state: if(snapshot.pass_ready?, do: "Ready", else: "Action needed"),
        tone: if(snapshot.pass_ready?, do: :success, else: :warning)
      },
      %{
        label: "Claimable names",
        copy: "#{snapshot.claimable_names} names ready",
        state: if(snapshot.claimable_names > 0, do: "Ready", else: "Action needed"),
        tone: if(snapshot.claimable_names > 0, do: :success, else: :warning)
      },
      %{
        label: "Billing",
        copy: setup_billing_copy(snapshot.billing_status),
        state: setup_billing_label(snapshot.billing_status),
        tone: setup_billing_tone(snapshot.billing_status)
      }
    ]
  end

  def setup_state_chip_class(:success),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  def setup_state_chip_class(:warning),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,#c58a24_48%,var(--border)_52%)] bg-[color:color-mix(in_oklch,#c58a24_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  def setup_state_chip_class(:neutral),
    do:
      "rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-1 text-xs text-[color:var(--muted-foreground)]"

  def readiness_steps(%{steps: steps}) when is_list(steps), do: steps
  def readiness_steps(_readiness), do: []

  def readiness_status_label("complete"), do: "Ready"
  def readiness_status_label("ready"), do: "Ready"
  def readiness_status_label("needs_action"), do: "Needs action"
  def readiness_status_label("waiting"), do: "Waiting"
  def readiness_status_label(_status), do: "Waiting"

  def readiness_state_chip_class(status) when status in ["complete", "ready"],
    do: setup_state_chip_class(:success)

  def readiness_state_chip_class("needs_action"), do: setup_state_chip_class(:warning)
  def readiness_state_chip_class(_status), do: setup_state_chip_class(:neutral)

  def name_claim_badge_class(true),
    do:
      "rounded-full border border-[color:#a6574f] bg-[color:color-mix(in_oklch,#a6574f_10%,transparent)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:#a6574f]"

  def name_claim_badge_class(false),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,#c58a24_48%,var(--border)_52%)] bg-[color:color-mix(in_oklch,#c58a24_10%,transparent)] px-3 py-1 text-xs uppercase tracking-[0.16em] text-[color:var(--foreground)]"

  def billing_next_ready_path(%{available_claims: [claim | _]}),
    do: "/app/billing?claimedLabel=#{claim.label}"

  def billing_next_ready_path(_services), do: "/app/billing"

  def launch_progress_items(formation) do
    steps = [
      %{
        key: "reserve_claim",
        title: "Reserve company name",
        copy: "We reserve the identity and lock in the selected name."
      },
      %{
        key: "create_sprite",
        title: "Prepare hosted company",
        copy: "The hosted environment is being set up for launch."
      },
      %{
        key: "bootstrap_workspace",
        title: "Build company workspace",
        copy: "The company workspace and assistant are being prepared."
      },
      %{
        key: "verify_runtime",
        title: "Check company response",
        copy: "We confirm the company is responding before opening it."
      },
      %{
        key: "activate_subdomain",
        title: "Open public page",
        copy: "The live public company page is being switched on."
      },
      %{
        key: "finalize",
        title: "Open dashboard",
        copy: "Final checks finish before the dashboard opens."
      }
    ]

    current_step = formation && launch_progress_step_key(formation.current_step)
    current_index = Enum.find_index(steps, &(&1.key == current_step)) || 0

    steps
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      state =
        cond do
          formation && formation.status == "succeeded" -> :complete
          index < current_index -> :complete
          index == current_index -> :current
          true -> :upcoming
        end

      badge =
        case state do
          :complete -> "Done"
          :current -> "Working"
          :upcoming -> "Next"
        end

      Map.merge(item, %{state: state, badge: badge})
    end)
  end

  def launch_progress_badge_class(:complete),
    do:
      "rounded-full border border-[color:color-mix(in_oklch,var(--positive)_50%,var(--border)_50%)] bg-[color:color-mix(in_oklch,var(--positive)_12%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  def launch_progress_badge_class(:current),
    do:
      "rounded-full border border-[color:var(--ring)] bg-[color:color-mix(in_oklch,var(--ring)_10%,transparent)] px-3 py-1 text-xs text-[color:var(--foreground)]"

  def launch_progress_badge_class(:upcoming),
    do:
      "rounded-full border border-[color:var(--border)] bg-[color:var(--background)] px-3 py-1 text-xs text-[color:var(--muted-foreground)]"

  def eligible_services?(services),
    do:
      length(services.holdings.animata1) + length(services.holdings.animata2) +
        length(services.holdings.animata_pass) > 0

  def total_eligible_tokens(formation) do
    length(formation.collections.animata1) + length(formation.collections.animata2) +
      length(formation.collections.animata_pass)
  end

  def active_formation?(formation) do
    Enum.any?(formation.active_formations, &(&1.status in ["queued", "running"]))
  end

  defp formation_active?(%{status: status}) when status in ["queued", "running"], do: true
  defp formation_active?(_formation), do: false

  defp empty_setup_snapshot do
    %{
      wallet_connected?: false,
      pass_ready?: false,
      claimable_names: 0,
      billing_status: :not_started,
      company_opened?: false,
      company_opening?: false
    }
  end

  defp setup_billing_status(%{connected: true}), do: :connected
  defp setup_billing_status(%{status: "checkout_open"}), do: :pending
  defp setup_billing_status(_billing), do: :not_started

  def available_claim_count(%{available_claims: claims}) when is_list(claims), do: length(claims)
  def available_claim_count(_source), do: 0

  defp owned_company_count(%{owned_companies: companies}) when is_list(companies),
    do: length(companies)

  defp owned_company_count(_source), do: 0

  defp setup_step_state(1, snapshot, _current_step) do
    if snapshot.wallet_connected? and snapshot.pass_ready?, do: :complete, else: :current
  end

  defp setup_step_state(2, snapshot, current_step) do
    cond do
      snapshot.claimable_names > 0 -> :complete
      current_step == 2 -> :current
      true -> :upcoming
    end
  end

  defp setup_step_state(3, snapshot, current_step) do
    cond do
      snapshot.billing_status == :connected -> :complete
      current_step == 3 -> :current
      true -> :upcoming
    end
  end

  defp setup_step_state(4, snapshot, current_step) do
    cond do
      snapshot.company_opened? -> :complete
      current_step == 4 -> :current
      true -> :upcoming
    end
  end

  defp setup_billing_label(:connected), do: "Connected"
  defp setup_billing_label(:pending), do: "Pending"
  defp setup_billing_label(:not_started), do: "Not started"

  defp setup_billing_copy(:connected), do: "Billing is active"
  defp setup_billing_copy(:pending), do: "Finishing setup"
  defp setup_billing_copy(:not_started), do: "Add a payment method"

  defp setup_billing_tone(:connected), do: :success
  defp setup_billing_tone(:pending), do: :warning
  defp setup_billing_tone(:not_started), do: :neutral

  defp launch_progress_step_key("bootstrap_sprite"), do: "create_sprite"
  defp launch_progress_step_key(step), do: step
end
