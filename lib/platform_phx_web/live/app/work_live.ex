defmodule PlatformPhxWeb.App.WorkLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  import PlatformPhxWeb.App.RwrComponents

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Work")
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
      header_title="Work"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-work-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="space-y-6" data-dashboard-block>
          <.company_switcher companies={@companies} selected_company={@company} path={~p"/app/work"} />

          <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="font-display text-[2.4rem] leading-none text-[color:var(--foreground)]">
                Work
              </p>
              <p class="mt-2 max-w-[44rem] text-[0.98rem] leading-7 text-[color:var(--muted-foreground)]">
                Review active work, assigned workers, and the latest run for this company.
              </p>
            </div>
            <button
              type="button"
              class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--muted-foreground)] opacity-70"
              disabled
            >
              Publish selected work
            </button>
          </div>

          <%= cond do %>
            <% is_nil(@current_human) -> %>
              <.empty_state
                title="Sign in to see company work."
                copy="Work appears after you sign in and open a company."
              />
            <% is_nil(@company) -> %>
              <.empty_state
                title="Open a company to track work."
                copy="Work items, runs, workers, and proof will appear here after a company exists."
              />
            <% @items == [] -> %>
              <.empty_state
                title="No work items yet."
                copy="New work will appear here with its assigned worker, how it will run, and latest status."
              />
            <% true -> %>
              <section class="overflow-hidden border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)]">
                <div class="grid grid-cols-[minmax(14rem,1.4fr)_8rem_minmax(11rem,1fr)_minmax(10rem,1fr)_10rem] gap-4 border-b border-[color:var(--border)] px-4 py-3 text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] max-xl:hidden">
                  <span>Work item</span>
                  <span>Status</span>
                  <span>Assigned worker</span>
                  <span>Runs with</span>
                  <span>Latest run</span>
                </div>
                <div class="divide-y divide-[color:var(--border)]">
                  <div
                    :for={item <- @items}
                    class="grid gap-3 px-4 py-4 text-[0.95rem] xl:grid-cols-[minmax(14rem,1.4fr)_8rem_minmax(11rem,1fr)_minmax(10rem,1fr)_10rem] xl:items-center"
                  >
                    <div class="min-w-0">
                      <p class="truncate font-display text-[1.45rem] leading-none text-[color:var(--foreground)]">
                        {item.title}
                      </p>
                      <p class="mt-2 line-clamp-2 text-[0.86rem] leading-6 text-[color:var(--muted-foreground)]">
                        {item.body || "No notes added."}
                      </p>
                    </div>
                    <.mobile_fact label="Status" value={status_label(item.status)} />
                    <.mobile_fact label="Assigned worker" value={worker_name(item.assigned_worker)} />
                    <.mobile_fact label="Runs with" value={runs_with_label(item.desired_runner_kind)} />
                    <div class="min-w-0">
                      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] xl:hidden">
                        Latest run
                      </p>
                      <%= case Map.get(@latest_runs, item.id) do %>
                        <% nil -> %>
                          <span class="mt-1 block text-[color:var(--muted-foreground)] xl:mt-0">
                            No run yet
                          </span>
                        <% run -> %>
                          <.link
                            navigate={~p"/app/runs/#{run.id}"}
                            class="mt-1 block text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4 xl:mt-0"
                          >
                            {status_label(run.status)}
                          </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </section>
          <% end %>

          <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
            Publishing stays off until this company has review and publishing steps ready.
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp mobile_fact(assigns) do
    ~H"""
    <div>
      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] xl:hidden">
        {@label}
      </p>
      <p class="mt-1 text-[color:var(--foreground)] xl:mt-0">{@value}</p>
    </div>
    """
  end

  defp load_payload(socket, params) do
    companies = AgentPlatform.list_owned_companies(socket.assigns.current_human)
    company = selected_company(companies, params)
    items = list_items(socket.assigns.current_human, company)
    latest_runs = latest_runs(items)

    socket
    |> assign(:companies, companies)
    |> assign(:company, company)
    |> assign(:items, items)
    |> assign(:latest_runs, latest_runs)
  end

  defp selected_company([], _params), do: nil

  defp selected_company(companies, %{"company_id" => id}) do
    Enum.find(companies, &(to_string(&1.id) == id)) || List.first(companies)
  end

  defp selected_company(companies, _params), do: List.first(companies)

  defp list_items(nil, _company), do: []
  defp list_items(_human, nil), do: []
  defp list_items(human, company), do: Work.list_items_for_owned_company(human.id, company.id)

  defp latest_runs([]), do: %{}

  defp latest_runs(items) do
    items
    |> Enum.map(& &1.id)
    |> WorkRuns.list_runs_for_work_items()
    |> Enum.reduce(%{}, fn run, latest ->
      Map.put_new(latest, run.work_item_id, run)
    end)
  end
end
