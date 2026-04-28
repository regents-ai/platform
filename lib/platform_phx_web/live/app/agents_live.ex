defmodule PlatformPhxWeb.App.AgentsLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentRegistry
  import PlatformPhxWeb.App.RwrComponents

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Connected agents")
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
      header_title="Connected agents"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-agents-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="space-y-6" data-dashboard-block>
          <.company_switcher
            companies={@companies}
            selected_company={@company}
            path={~p"/app/agents"}
          />

          <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="font-display text-[2.4rem] leading-none text-[color:var(--foreground)]">
                Connected agents and workers
              </p>
              <p class="mt-2 max-w-[46rem] text-[0.98rem] leading-7 text-[color:var(--muted-foreground)]">
                Review agent profiles, worker roles, execution pools, relationships, and latest check-ins.
              </p>
            </div>
            <button
              type="button"
              class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--muted-foreground)] opacity-70"
              disabled
            >
              Publish worker proof
            </button>
          </div>

          <%= cond do %>
            <% is_nil(@current_human) -> %>
              <.empty_state
                title="Sign in to see connected workers."
                copy="Agent and worker status appears after you sign in and open a company."
              />
            <% is_nil(@company) -> %>
              <.empty_state
                title="No company yet."
                copy="Open a company to connect agents and workers."
              />
            <% @profiles == [] and @workers == [] -> %>
              <.empty_state
                title="No agents connected."
                copy="Connected profiles and workers will appear here with their roles and latest check-ins."
              />
            <% true -> %>
              <section class="grid gap-5 xl:grid-cols-[minmax(0,1.1fr)_minmax(22rem,0.9fr)]">
                <div class="space-y-4">
                  <article
                    :for={profile <- @profiles}
                    class="border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] px-4 py-5"
                  >
                    <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                      <div>
                        <p class="font-display text-[1.8rem] leading-none text-[color:var(--foreground)]">
                          {profile.name}
                        </p>
                        <p class="mt-2 max-w-[38rem] text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
                          {profile.public_description || "No description added."}
                        </p>
                      </div>
                      <span class="text-[0.88rem] text-[color:var(--muted-foreground)]">
                        {status_label(profile.status)}
                      </span>
                    </div>

                    <div class="mt-5 grid gap-4 sm:grid-cols-3">
                      <.fact label="Runs with" value={runs_with_label(profile.default_runner_kind)} />
                      <.fact label="Trust" value={trust_label(profile.trust_level)} />
                      <.fact label="Visibility" value={visibility_label(profile.default_visibility)} />
                    </div>

                    <div class="mt-5 grid gap-5 lg:grid-cols-2">
                      <section>
                        <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                          Workers
                        </p>
                        <div
                          :if={Map.get(@workers_by_profile, profile.id, []) == []}
                          class="mt-2 text-[0.88rem] text-[color:var(--muted-foreground)]"
                        >
                          No worker is assigned to this profile.
                        </div>
                        <div
                          :for={worker <- Map.get(@workers_by_profile, profile.id, [])}
                          class="mt-2 flex items-center justify-between gap-3 text-[0.9rem]"
                        >
                          <span class="text-[color:var(--foreground)]">{worker.name}</span>
                          <span class="text-[color:var(--muted-foreground)]">
                            {role_label(worker.worker_role)}
                          </span>
                        </div>
                      </section>

                      <section>
                        <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                          Execution pool
                        </p>
                        <div
                          :if={Map.get(@execution_pools, profile.id, []) == []}
                          class="mt-2 text-[0.88rem] text-[color:var(--muted-foreground)]"
                        >
                          No available workers in this pool.
                        </div>
                        <div
                          :for={worker <- Map.get(@execution_pools, profile.id, [])}
                          class="mt-2 flex items-center justify-between gap-3 text-[0.9rem]"
                        >
                          <span class="text-[color:var(--foreground)]">{worker.name}</span>
                          <span class="text-[color:var(--muted-foreground)]">
                            {status_label(worker.status)}
                          </span>
                        </div>
                      </section>
                    </div>
                  </article>
                </div>

                <aside class="space-y-5">
                  <section class="border border-[color:var(--border)] px-4 py-4">
                    <p class="font-display text-[1.6rem] leading-none text-[color:var(--foreground)]">
                      Worker status
                    </p>
                    <div
                      :if={@workers == []}
                      class="mt-3 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]"
                    >
                      No workers registered yet.
                    </div>
                    <div
                      :for={worker <- @workers}
                      class="mt-4 border-t border-[color:var(--border)] pt-4"
                    >
                      <div class="flex items-start justify-between gap-3">
                        <div>
                          <p class="text-[color:var(--foreground)]">{worker.name}</p>
                          <p class="mt-1 text-[0.84rem] text-[color:var(--muted-foreground)]">
                            {role_label(worker.worker_role)} · {surface_label(
                              worker.execution_surface
                            )}
                          </p>
                        </div>
                        <span class="text-[0.84rem] text-[color:var(--muted-foreground)]">
                          {status_label(worker.status)}
                        </span>
                      </div>
                      <div class="mt-3 grid gap-3">
                        <.fact label="Assigned worker" value={worker.name} />
                        <.fact label="Runs with" value={runs_with_label(worker.runner_kind)} />
                        <.fact
                          label="Last check-in"
                          value={heartbeat_label(worker.last_heartbeat_at)}
                        />
                      </div>
                    </div>
                  </section>

                  <section class="border border-[color:var(--border)] px-4 py-4">
                    <p class="font-display text-[1.6rem] leading-none text-[color:var(--foreground)]">
                      Relationships
                    </p>
                    <div
                      :if={@relationships == []}
                      class="mt-3 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]"
                    >
                      No worker relationships yet.
                    </div>
                    <div
                      :for={relationship <- @relationships}
                      class="mt-4 border-t border-[color:var(--border)] pt-4"
                    >
                      <p class="text-[color:var(--foreground)]">
                        {relationship_label(relationship.relationship_kind)}
                      </p>
                      <p class="mt-1 text-[0.84rem] leading-6 text-[color:var(--muted-foreground)]">
                        {relationship_source(relationship, @names_by_id)} to {relationship_target(
                          relationship,
                          @names_by_id
                        )}
                      </p>
                    </div>
                  </section>

                  <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
                    Worker proof can be published after an operator reviews the relationship and latest check-in.
                  </section>
                </aside>
              </section>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket, params) do
    companies = AgentPlatform.list_owned_companies(socket.assigns.current_human)
    company = selected_company(companies, params)
    profiles = profiles(company)
    workers = workers(company)
    relationships = relationships(company)

    socket
    |> assign(:companies, companies)
    |> assign(:company, company)
    |> assign(:profiles, profiles)
    |> assign(:workers, workers)
    |> assign(:relationships, relationships)
    |> assign(:workers_by_profile, Enum.group_by(workers, & &1.agent_profile_id))
    |> assign(:execution_pools, execution_pools(company, profiles))
    |> assign(:names_by_id, names_by_id(profiles, workers))
  end

  defp selected_company([], _params), do: nil

  defp selected_company(companies, %{"company_id" => id}) do
    Enum.find(companies, &(to_string(&1.id) == id)) || List.first(companies)
  end

  defp selected_company(companies, _params), do: List.first(companies)

  defp profiles(nil), do: []
  defp profiles(company), do: AgentRegistry.list_agent_profiles_with_workers(company.id)

  defp workers(nil), do: []
  defp workers(company), do: AgentRegistry.list_workers_with_details(company.id)

  defp relationships(nil), do: []
  defp relationships(company), do: AgentRegistry.list_relationships(company.id)

  defp execution_pools(nil, _profiles), do: %{}

  defp execution_pools(company, profiles) do
    Map.new(profiles, fn profile ->
      {profile.id, AgentRegistry.list_execution_pool(company.id, profile.id)}
    end)
  end

  defp names_by_id(profiles, workers) do
    profile_names = Map.new(profiles, &{{:profile, &1.id}, &1.name})
    worker_names = Map.new(workers, &{{:worker, &1.id}, &1.name})
    Map.merge(profile_names, worker_names)
  end

  defp relationship_source(relationship, names) do
    Map.get(names, {:profile, relationship.source_agent_profile_id}) ||
      Map.get(names, {:worker, relationship.source_worker_id}) ||
      "Unknown"
  end

  defp relationship_target(relationship, names) do
    Map.get(names, {:profile, relationship.target_agent_profile_id}) ||
      Map.get(names, {:worker, relationship.target_worker_id}) ||
      "Unknown"
  end

  defp trust_label("delegated"), do: "Delegated"
  defp trust_label("summaries_only"), do: "Summaries only"
  defp trust_label(value) when is_binary(value), do: status_label(value)
  defp trust_label(_value), do: "Standard"

  defp visibility_label("operator"), do: "Operators"
  defp visibility_label("company"), do: "Company"
  defp visibility_label("public"), do: "Public"
  defp visibility_label(_visibility), do: "Operators"
end
