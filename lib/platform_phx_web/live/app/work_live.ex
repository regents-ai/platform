defmodule PlatformPhxWeb.App.WorkLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentRegistry
  alias PlatformPhx.AgentPlatform.Companies
  alias PlatformPhx.Work
  alias PlatformPhx.WorkRuns
  import PlatformPhxWeb.App.RwrComponents

  @async_runner_kinds ["codex_exec", "codex_app_server", "fake"]

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
  def handle_event("create_work", params, socket) do
    with {:ok, attrs} <- create_work_attrs(socket, params),
         {:ok, _item} <- Work.create_item(attrs) do
      {:noreply,
       socket
       |> put_flash(:info, "Work added.")
       |> load_payload(socket.assigns.params)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Work could not be added.")}
    end
  end

  @impl true
  def handle_event("start_run", %{"item_id" => item_id}, socket) do
    with item when not is_nil(item) <- owned_item(socket, item_id),
         worker when not is_nil(worker) <- item.assigned_worker,
         {:ok, run} <- create_run(item, worker),
         {:ok, _assignment_or_job} <- after_run_created(worker, run) do
      {:noreply,
       socket
       |> put_flash(:info, "Run started.")
       |> load_payload(socket.assigns.params)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Run could not be started.")}
    end
  end

  @impl true
  def handle_event("publish_run_artifacts", %{"run_id" => run_id}, socket) do
    with run when not is_nil(run) <- owned_run(socket, run_id),
         [_artifact | _rest] = artifacts <- WorkRuns.list_artifacts(run.company_id, run.id),
         {:ok, _published} <- publish_artifacts(artifacts) do
      {:noreply,
       socket
       |> put_flash(:info, "Proof published.")
       |> load_payload(socket.assigns.params)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Proof could not be published.")}
    end
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
            <.link
              :if={@company}
              navigate={~p"/app/runtimes"}
              class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
            >
              Review runtimes
            </.link>
          </div>

          <section
            :if={@company}
            class="border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)] px-4 py-4"
          >
            <.form
              for={@work_form}
              id="create-work-form"
              phx-submit="create_work"
              class="grid gap-3 lg:grid-cols-[minmax(12rem,1fr)_minmax(16rem,1.4fr)_minmax(12rem,0.8fr)_auto] lg:items-end"
            >
              <label class="grid gap-1">
                <span class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                  Work name
                </span>
                <input
                  type="text"
                  name="title"
                  required
                  placeholder="Prepare weekly update"
                  class="min-h-11 border border-[color:var(--border)] bg-[color:var(--background)] px-3 text-[0.95rem] text-[color:var(--foreground)] outline-none transition duration-150 ease-[var(--ease-out-quart)] focus:border-[color:var(--foreground)]"
                />
              </label>
              <label class="grid gap-1">
                <span class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                  Notes
                </span>
                <input
                  type="text"
                  name="body"
                  placeholder="What should the worker do?"
                  class="min-h-11 border border-[color:var(--border)] bg-[color:var(--background)] px-3 text-[0.95rem] text-[color:var(--foreground)] outline-none transition duration-150 ease-[var(--ease-out-quart)] focus:border-[color:var(--foreground)]"
                />
              </label>
              <label class="grid gap-1">
                <span class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                  Assigned worker
                </span>
                <select
                  name="worker_id"
                  required
                  class="min-h-11 border border-[color:var(--border)] bg-[color:var(--background)] px-3 text-[0.95rem] text-[color:var(--foreground)] outline-none transition duration-150 ease-[var(--ease-out-quart)] focus:border-[color:var(--foreground)]"
                >
                  <option value="">Choose worker</option>
                  <option :for={worker <- @workers} value={worker.id}>
                    {worker_name(worker)} · {runs_with_label(worker.runner_kind)}
                  </option>
                </select>
              </label>
              <button
                type="submit"
                disabled={@workers == []}
                class="min-h-11 rounded-md border border-[color:var(--foreground)] bg-[color:var(--foreground)] px-4 text-[0.9rem] text-[color:var(--background)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
              >
                Add work
              </button>
            </.form>
          </section>

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
                <div class="grid grid-cols-[minmax(14rem,1.4fr)_8rem_minmax(11rem,1fr)_minmax(10rem,1fr)_10rem_10rem_9rem] gap-4 border-b border-[color:var(--border)] px-4 py-3 text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] max-xl:hidden">
                  <span>Work item</span>
                  <span>Status</span>
                  <span>Assigned worker</span>
                  <span>Runs with</span>
                  <span>Latest run</span>
                  <span>Proof</span>
                  <span>Action</span>
                </div>
                <div class="divide-y divide-[color:var(--border)]">
                  <div
                    :for={item <- @items}
                    class="grid gap-3 px-4 py-4 text-[0.95rem] xl:grid-cols-[minmax(14rem,1.4fr)_8rem_minmax(11rem,1fr)_minmax(10rem,1fr)_10rem_10rem_9rem] xl:items-center"
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
                    <div class="min-w-0">
                      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] xl:hidden">
                        Proof
                      </p>
                      <%= case Map.get(@latest_runs, item.id) do %>
                        <% nil -> %>
                          <span class="mt-1 block text-[color:var(--muted-foreground)] xl:mt-0">
                            No proof yet
                          </span>
                        <% run -> %>
                          <p class="mt-1 text-[color:var(--foreground)] xl:mt-0">
                            {proof_summary(run, @artifact_counts, @approval_counts)}
                          </p>
                          <button
                            type="button"
                            phx-click="publish_run_artifacts"
                            phx-value-run_id={run.id}
                            disabled={Map.get(@artifact_counts, run.id, 0) == 0}
                            class="mt-2 rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.82rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50 xl:mt-1"
                          >
                            Publish
                          </button>
                      <% end %>
                    </div>
                    <div class="min-w-0">
                      <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)] xl:hidden">
                        Action
                      </p>
                      <button
                        type="button"
                        phx-click="start_run"
                        phx-value-item_id={item.id}
                        disabled={is_nil(item.assigned_worker)}
                        class="mt-1 rounded-md border border-[color:var(--foreground)] bg-[color:var(--foreground)] px-3 py-2 text-[0.82rem] text-[color:var(--background)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50 xl:mt-0"
                      >
                        Start run
                      </button>
                    </div>
                  </div>
                </div>
              </section>
          <% end %>

          <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
            Publish proof after the work is ready to share.
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
    companies = Companies.list_owned_companies(socket.assigns.current_human)
    company = selected_company(companies, params)
    items = list_items(socket.assigns.current_human, company)
    workers = workers(company)
    latest_runs = latest_runs(items)
    artifact_counts = artifact_counts(latest_runs)
    approval_counts = approval_counts(latest_runs)

    socket
    |> assign(:companies, companies)
    |> assign(:company, company)
    |> assign(:params, params)
    |> assign(:items, items)
    |> assign(:workers, workers)
    |> assign(:work_form, %{})
    |> assign(:latest_runs, latest_runs)
    |> assign(:artifact_counts, artifact_counts)
    |> assign(:approval_counts, approval_counts)
  end

  defp selected_company([], _params), do: nil

  defp selected_company(companies, %{"company_id" => id}) do
    Enum.find(companies, &(to_string(&1.id) == id)) || List.first(companies)
  end

  defp selected_company(companies, _params), do: List.first(companies)

  defp list_items(nil, _company), do: []
  defp list_items(_human, nil), do: []
  defp list_items(human, company), do: Work.list_items_for_owned_company(human.id, company.id)

  defp workers(nil), do: []
  defp workers(company), do: AgentRegistry.list_workers(company.id)

  defp owned_item(socket, item_id) do
    Enum.find(socket.assigns.items, &(to_string(&1.id) == to_string(item_id)))
  end

  defp owned_run(socket, run_id) do
    socket.assigns.latest_runs
    |> Map.values()
    |> Enum.find(&(to_string(&1.id) == to_string(run_id)))
  end

  defp create_work_attrs(socket, params) do
    with company when not is_nil(company) <- socket.assigns.company,
         worker when not is_nil(worker) <- selected_worker(socket.assigns.workers, params) do
      {:ok,
       %{
         company_id: company.id,
         assigned_agent_profile_id: worker.agent_profile_id,
         assigned_worker_id: worker.id,
         title: Map.get(params, "title"),
         body: Map.get(params, "body"),
         status: "ready",
         desired_runner_kind: worker.runner_kind
       }}
    else
      _error -> {:error, :invalid_work}
    end
  end

  defp selected_worker(workers, params) do
    Enum.find(workers, &(to_string(&1.id) == to_string(Map.get(params, "worker_id"))))
  end

  defp create_run(item, worker) do
    WorkRuns.create_run(%{
      company_id: item.company_id,
      work_item_id: item.id,
      worker_id: worker.id,
      runtime_profile_id: worker.runtime_profile_id,
      runner_kind: item.desired_runner_kind || worker.runner_kind
    })
  end

  defp after_run_created(%{execution_surface: "local_bridge"} = worker, run) do
    AgentRegistry.create_worker_assignment(worker.company_id, worker.id, %{work_run_id: run.id})
  end

  defp after_run_created(_worker, %{runner_kind: runner_kind} = run)
       when runner_kind in @async_runner_kinds do
    WorkRuns.enqueue_start(run)
  end

  defp after_run_created(_worker, _run), do: {:error, :unsupported_run}

  defp publish_artifacts(artifacts) do
    artifacts
    |> Enum.reduce_while({:ok, []}, fn artifact, {:ok, published} ->
      case WorkRuns.publish_artifact(artifact) do
        {:ok, artifact} -> {:cont, {:ok, [artifact | published]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp latest_runs([]), do: %{}

  defp latest_runs(items) do
    items
    |> Enum.map(& &1.id)
    |> WorkRuns.list_runs_for_work_items()
    |> Enum.reduce(%{}, fn run, latest ->
      Map.put_new(latest, run.work_item_id, run)
    end)
  end

  defp artifact_counts(latest_runs) do
    latest_runs
    |> Map.values()
    |> Map.new(fn run ->
      {run.id, length(WorkRuns.list_artifacts(run.company_id, run.id))}
    end)
  end

  defp approval_counts(latest_runs) do
    latest_runs
    |> Map.values()
    |> Map.new(fn run ->
      {run.id, length(WorkRuns.list_approval_requests(run.company_id, run.id))}
    end)
  end

  defp proof_summary(run, artifact_counts, approval_counts) do
    artifacts = Map.get(artifact_counts, run.id, 0)
    approvals = Map.get(approval_counts, run.id, 0)

    cond do
      artifacts > 0 and approvals > 0 -> "#{artifacts} proof, #{approvals} approval"
      artifacts > 0 -> "#{artifacts} proof"
      approvals > 0 -> "#{approvals} approval"
      true -> "No proof yet"
    end
  end
end
