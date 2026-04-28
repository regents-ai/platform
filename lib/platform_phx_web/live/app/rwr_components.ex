defmodule PlatformPhxWeb.App.RwrComponents do
  @moduledoc false

  use PlatformPhxWeb, :html

  attr :companies, :list, required: true
  attr :selected_company, :map, default: nil
  attr :path, :string, required: true

  def company_switcher(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 border-b border-[color:var(--border)] pb-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <p class="font-display text-[2rem] leading-none text-[color:var(--foreground)]">
          {company_name(@selected_company)}
        </p>
        <p class="mt-1 text-[0.88rem] text-[color:var(--muted-foreground)]">
          Company workspace
        </p>
      </div>
      <div :if={length(@companies) > 1} class="flex flex-wrap gap-2">
        <.link
          :for={company <- @companies}
          navigate={"#{@path}?company_id=#{company.id}"}
          class={[
            "rounded-md border px-3 py-2 text-[0.84rem] transition duration-150 ease-[var(--ease-out-quart)] hover:-translate-y-0.5 focus-visible:-translate-y-0.5",
            @selected_company && company.id == @selected_company.id &&
              "border-[color:var(--foreground)] bg-[color:var(--foreground)] text-[color:var(--background)]",
            (!@selected_company || company.id != @selected_company.id) &&
              "border-[color:var(--border)] text-[color:var(--foreground)]"
          ]}
        >
          {company.name}
        </.link>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :copy, :string, required: true

  def empty_state(assigns) do
    ~H"""
    <section class="border border-dashed border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_76%,var(--card)_24%)] px-5 py-7">
      <p class="font-display text-[1.7rem] leading-none text-[color:var(--foreground)]">{@title}</p>
      <p class="mt-3 max-w-[42rem] text-[0.95rem] leading-7 text-[color:var(--muted-foreground)]">
        {@copy}
      </p>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def fact(assigns) do
    ~H"""
    <div class="min-w-0 border-l border-[color:var(--border)] pl-3">
      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
        {@label}
      </p>
      <p class="mt-1 truncate text-[0.96rem] text-[color:var(--foreground)]">{@value}</p>
    </div>
    """
  end

  def company_name(nil), do: "No company selected"
  def company_name(%{name: name}) when is_binary(name), do: name
  def company_name(_company), do: "Company"

  def status_label(nil), do: "Unknown"

  def status_label(status) when is_binary(status),
    do: status |> String.replace("_", " ") |> String.capitalize()

  def worker_name(nil), do: "Unassigned"
  def worker_name(%{name: name}) when is_binary(name), do: name
  def worker_name(_worker), do: "Assigned"

  def profile_name(nil), do: "Unassigned"
  def profile_name(%{name: name}) when is_binary(name), do: name
  def profile_name(_profile), do: "Assigned"

  def runs_with_label("hermes_local_manager"), do: "Hermes local manager"
  def runs_with_label("hermes_hosted_manager"), do: "Hermes hosted manager"
  def runs_with_label("openclaw_local_manager"), do: "OpenClaw local manager"
  def runs_with_label("openclaw_local_executor"), do: "OpenClaw local worker"
  def runs_with_label("openclaw_code_agent_local"), do: "OpenClaw code worker"
  def runs_with_label("codex_exec"), do: "Codex hosted worker"
  def runs_with_label("codex_app_server"), do: "Codex app worker"
  def runs_with_label("fake"), do: "Test worker"
  def runs_with_label("custom_worker"), do: "Custom worker"
  def runs_with_label(nil), do: "Not selected"
  def runs_with_label(_kind), do: "Configured worker"

  def surface_label("hosted_sprite"), do: "Hosted"
  def surface_label("local_bridge"), do: "Operator machine"
  def surface_label("external_webhook"), do: "Outside service"
  def surface_label(_surface), do: "Configured"

  def billing_label("platform_hosted"), do: "Billing available"
  def billing_label("user_local"), do: "Operator pays directly"
  def billing_label("external_self_reported"), do: "Reported by outside service"
  def billing_label(_mode), do: "Billing not shown"

  def role_label("manager"), do: "Manager"
  def role_label("executor"), do: "Executor"
  def role_label("hybrid"), do: "Manager and executor"
  def role_label(_role), do: "Worker"

  def relationship_label("manager_of"), do: "Manages"
  def relationship_label("preferred_executor"), do: "Preferred worker"
  def relationship_label("can_delegate_to"), do: "Can assign work to"
  def relationship_label("reports_to"), do: "Reports to"
  def relationship_label(_kind), do: "Related"

  def heartbeat_label(nil), do: "No check-in yet"

  def heartbeat_label(%DateTime{} = at) do
    Calendar.strftime(at, "%b %-d, %-I:%M %p")
  end

  def money_label(nil), do: "$0.00"
  def money_label(%Decimal{} = value), do: "$#{Decimal.round(value, 2)}"
  def money_label(value), do: to_string(value)

  def time_label(nil), do: "Not recorded"
  def time_label(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %-I:%M %p")
end
