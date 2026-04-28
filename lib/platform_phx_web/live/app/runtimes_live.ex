defmodule PlatformPhxWeb.App.RuntimesLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.RuntimeRegistry
  import PlatformPhxWeb.App.RwrComponents

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Runtimes")
     |> load_payload(params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_payload(socket, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="regents"
      header_eyebrow="App"
      header_title="Runtimes"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-runtimes-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="space-y-6" data-dashboard-block>
          <.company_switcher
            companies={@companies}
            selected_company={@company}
            path={~p"/app/runtimes"}
          />

          <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="font-display text-[2.4rem] leading-none text-[color:var(--foreground)]">
                Runtimes
              </p>
              <p class="mt-2 max-w-[45rem] text-[0.98rem] leading-7 text-[color:var(--muted-foreground)]">
                Check where company work can run, current status, usage, and saved checkpoints.
              </p>
            </div>
            <button
              type="button"
              class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--muted-foreground)] opacity-70"
              disabled
            >
              Publish runtime proof
            </button>
          </div>

          <%= cond do %>
            <% is_nil(@current_human) -> %>
              <.empty_state
                title="Sign in to see runtimes."
                copy="Runtime status appears after you sign in and open a company."
              />
            <% is_nil(@company) -> %>
              <.empty_state
                title="No company yet."
                copy="Open a company to see the places where work can run."
              />
            <% @runtimes == [] -> %>
              <.empty_state
                title="No runtimes connected."
                copy="Connected runtimes will appear here with status, usage, and checkpoints."
              />
            <% true -> %>
              <section class="divide-y divide-[color:var(--border)] border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)]">
                <article :for={runtime <- @runtimes} class="px-4 py-5">
                  <div class="grid gap-4 xl:grid-cols-[minmax(13rem,1fr)_minmax(0,2fr)]">
                    <div>
                      <p class="font-display text-[1.7rem] leading-none text-[color:var(--foreground)]">
                        {runtime.name}
                      </p>
                      <p class="mt-2 text-[0.9rem] text-[color:var(--muted-foreground)]">
                        {surface_label(runtime.execution_surface)}
                      </p>
                    </div>
                    <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                      <.fact label="Status" value={status_label(runtime.status)} />
                      <.fact label="Runs with" value={runs_with_label(runtime.runner_kind)} />
                      <.fact label="Billing" value={billing_label(runtime.billing_mode)} />
                      <.fact label="Usage" value={usage_summary(runtime, @usage_by_runtime)} />
                    </div>
                  </div>

                  <div class="mt-5 grid gap-4 lg:grid-cols-2">
                    <section>
                      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                        Services
                      </p>
                      <div
                        :if={Map.get(@services_by_runtime, runtime.id, []) == []}
                        class="mt-2 text-[0.88rem] text-[color:var(--muted-foreground)]"
                      >
                        No services shown yet.
                      </div>
                      <div
                        :for={service <- Map.get(@services_by_runtime, runtime.id, [])}
                        class="mt-2 flex items-center justify-between gap-3 text-[0.9rem]"
                      >
                        <span class="text-[color:var(--foreground)]">{service.name}</span>
                        <span class="text-[color:var(--muted-foreground)]">
                          {status_label(service.status)}
                        </span>
                      </div>
                    </section>

                    <section>
                      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                        Checkpoints
                      </p>
                      <div
                        :if={Map.get(@checkpoints_by_runtime, runtime.id, []) == []}
                        class="mt-2 text-[0.88rem] text-[color:var(--muted-foreground)]"
                      >
                        No checkpoints saved yet.
                      </div>
                      <div
                        :for={checkpoint <- Map.get(@checkpoints_by_runtime, runtime.id, [])}
                        class="mt-2 flex items-center justify-between gap-3 text-[0.9rem]"
                      >
                        <span class="truncate text-[color:var(--foreground)]">
                          {checkpoint.checkpoint_ref}
                        </span>
                        <span class="shrink-0 text-[color:var(--muted-foreground)]">
                          {status_label(checkpoint.status)}
                        </span>
                      </div>
                    </section>
                  </div>
                </article>
              </section>
          <% end %>

          <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
            Runtime proof can be published after an operator reviews the checkpoints.
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket, params) do
    companies = AgentPlatform.list_owned_companies(socket.assigns.current_human)
    company = selected_company(companies, params)

    runtimes = runtimes(company)
    services = records_by_runtime(services(company))
    checkpoints = records_by_runtime(checkpoints(company))
    usage = records_by_runtime(usage(company))

    socket
    |> assign(:companies, companies)
    |> assign(:company, company)
    |> assign(:runtimes, runtimes)
    |> assign(:services_by_runtime, services)
    |> assign(:checkpoints_by_runtime, checkpoints)
    |> assign(:usage_by_runtime, usage)
  end

  defp selected_company([], _params), do: nil

  defp selected_company(companies, %{"company_id" => id}) do
    Enum.find(companies, &(to_string(&1.id) == id)) || List.first(companies)
  end

  defp selected_company(companies, _params), do: List.first(companies)

  defp runtimes(nil), do: []
  defp runtimes(company), do: RuntimeRegistry.list_runtime_profiles_with_details(company.id)

  defp services(nil), do: []
  defp services(company), do: RuntimeRegistry.list_runtime_services(company.id)

  defp checkpoints(nil), do: []
  defp checkpoints(company), do: RuntimeRegistry.list_runtime_checkpoints(company.id)

  defp usage(nil), do: []
  defp usage(company), do: RuntimeRegistry.list_usage_snapshots(company.id)

  defp records_by_runtime(records) do
    Enum.group_by(records, & &1.runtime_profile_id)
  end

  defp usage_summary(runtime, usage_by_runtime) do
    case Map.get(usage_by_runtime, runtime.id, []) do
      [] ->
        "No usage yet"

      [latest | _rest] ->
        minutes = div(latest.active_seconds || 0, 60)
        "#{minutes} min, #{money_label(latest.estimated_cost_usd)}"
    end
  end
end
