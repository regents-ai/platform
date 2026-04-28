defmodule PlatformPhxWeb.App.RunLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns
  import PlatformPhxWeb.App.RwrComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Run")
     |> load_payload(id)}
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
      header_title="Run"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="app-run-root"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="DashboardReveal"
      >
        <div class="space-y-6" data-dashboard-block>
          <.link
            navigate={~p"/app/work"}
            class="text-[0.9rem] text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4"
          >
            Back to work
          </.link>

          <%= if @run do %>
            <section class="border-b border-[color:var(--border)] pb-5">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <p class="font-display text-[2.5rem] leading-none text-[color:var(--foreground)]">
                    {@run.work_item.title}
                  </p>
                  <p class="mt-2 max-w-[46rem] text-[0.96rem] leading-7 text-[color:var(--muted-foreground)]">
                    {@run.summary || "No run summary has been added yet."}
                  </p>
                </div>
                <button
                  type="button"
                  class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--muted-foreground)] opacity-70"
                  disabled
                >
                  Publish run summary
                </button>
              </div>
              <div class="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
                <.fact label="Status" value={status_label(@run.status)} />
                <.fact label="Assigned worker" value={worker_name(@run.worker)} />
                <.fact label="Runs with" value={runs_with_label(@run.runner_kind)} />
                <.fact label="Cost" value={money_label(@run.cost_usd)} />
                <.fact label="Updated" value={time_label(@run.updated_at)} />
              </div>
            </section>

            <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_24rem]">
              <div class="space-y-5">
                <section class="border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)]">
                  <div class="border-b border-[color:var(--border)] px-4 py-3">
                    <p class="font-display text-[1.6rem] leading-none text-[color:var(--foreground)]">
                      Run path
                    </p>
                  </div>
                  <div class="grid gap-3 px-4 py-4 sm:grid-cols-3">
                    <.fact label="Parent run" value={run_ref(@run.parent_run)} />
                    <.fact label="Root run" value={run_ref(@run.root_run)} />
                    <.fact label="Assigned by" value={run_ref(@run.delegated_by_run)} />
                  </div>
                  <div class="border-t border-[color:var(--border)] px-4 py-4">
                    <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                      Child runs
                    </p>
                    <div
                      :if={@children == []}
                      class="mt-2 text-[0.9rem] text-[color:var(--muted-foreground)]"
                    >
                      No child runs yet.
                    </div>
                    <div
                      :for={child <- @children}
                      class="mt-3 flex items-center justify-between gap-4"
                    >
                      <.link
                        navigate={~p"/app/runs/#{child.id}"}
                        class="text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4"
                      >
                        Run #{child.id}
                      </.link>
                      <span class="text-[0.88rem] text-[color:var(--muted-foreground)]">
                        {status_label(child.status)}
                      </span>
                    </div>
                  </div>
                </section>

                <section class="border border-[color:var(--border)] bg-[color:color-mix(in_oklch,var(--background)_82%,var(--card)_18%)]">
                  <div class="border-b border-[color:var(--border)] px-4 py-3">
                    <p class="font-display text-[1.6rem] leading-none text-[color:var(--foreground)]">
                      Event timeline
                    </p>
                  </div>
                  <div :if={@events == []} class="px-4 py-5">
                    <.empty_state
                      title="No events yet."
                      copy="Progress updates will appear here as the worker moves through the run."
                    />
                  </div>
                  <div class="divide-y divide-[color:var(--border)]">
                    <div
                      :for={event <- @events}
                      class="grid gap-3 px-4 py-4 sm:grid-cols-[5rem_minmax(0,1fr)_12rem] sm:items-center"
                    >
                      <p class="font-display text-[1.35rem] leading-none text-[color:var(--foreground)]">
                        #{event.sequence}
                      </p>
                      <div>
                        <p class="text-[color:var(--foreground)]">{event_label(event.kind)}</p>
                        <p class="mt-1 text-[0.84rem] text-[color:var(--muted-foreground)]">
                          {event_copy(event)}
                        </p>
                      </div>
                      <p class="text-[0.84rem] text-[color:var(--muted-foreground)] sm:text-right">
                        {time_label(event.occurred_at)}
                      </p>
                    </div>
                  </div>
                </section>
              </div>

              <aside class="space-y-5">
                <section class="border border-[color:var(--border)] px-4 py-4">
                  <p class="font-display text-[1.5rem] leading-none text-[color:var(--foreground)]">
                    Artifacts
                  </p>
                  <div
                    :if={@artifacts == []}
                    class="mt-3 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]"
                  >
                    No artifacts have been attached yet.
                  </div>
                  <div
                    :for={artifact <- @artifacts}
                    class="mt-4 border-t border-[color:var(--border)] pt-4"
                  >
                    <p class="text-[color:var(--foreground)]">
                      {artifact.title || status_label(artifact.kind)}
                    </p>
                    <p class="mt-1 text-[0.84rem] text-[color:var(--muted-foreground)]">
                      {artifact.attestation_level |> attestation_label()}
                    </p>
                  </div>
                </section>

                <section class="border border-[color:var(--border)] px-4 py-4">
                  <p class="font-display text-[1.5rem] leading-none text-[color:var(--foreground)]">
                    Approvals
                  </p>
                  <div
                    :if={@approvals == []}
                    class="mt-3 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]"
                  >
                    No approvals are waiting on this run.
                  </div>
                  <div
                    :for={approval <- @approvals}
                    class="mt-4 border-t border-[color:var(--border)] pt-4"
                  >
                    <p class="text-[color:var(--foreground)]">{status_label(approval.status)}</p>
                    <p class="mt-1 text-[0.84rem] leading-6 text-[color:var(--muted-foreground)]">
                      {approval.risk_summary || "Approval request is waiting for review."}
                    </p>
                  </div>
                </section>

                <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
                  Publishing stays off until an operator reviews the run and attached proof.
                </section>
              </aside>
            </section>
          <% else %>
            <.empty_state
              title="Run not found."
              copy="Choose a run from the work page to review its timeline, proof, and approvals."
            />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_payload(socket, id) do
    run = owned_run(socket.assigns.current_human, id)

    socket
    |> assign(:run, run)
    |> assign(:children, children(run))
    |> assign(:events, events(run))
    |> assign(:artifacts, artifacts(run))
    |> assign(:approvals, approvals(run))
  end

  defp owned_run(nil, _id), do: nil

  defp owned_run(human, id) do
    case Integer.parse(id) do
      {run_id, ""} -> WorkRuns.get_owned_run(human.id, run_id)
      _ -> nil
    end
  end

  defp children(nil), do: []
  defp children(run), do: WorkRuns.list_child_runs(run.id)

  defp events(nil), do: []
  defp events(run), do: RunEvents.list_events(run.company_id, run.id)

  defp artifacts(nil), do: []
  defp artifacts(run), do: WorkRuns.list_artifacts(run.company_id, run.id)

  defp approvals(nil), do: []
  defp approvals(run), do: WorkRuns.list_approval_requests(run.company_id, run.id)

  defp run_ref(nil), do: "None"
  defp run_ref(%{id: id, status: status}), do: "Run #{id}, #{status_label(status)}"

  defp event_copy(%{sensitivity: sensitivity}) when sensitivity in ["sensitive", "secret"] do
    "Details are hidden on this page."
  end

  defp event_copy(_event), do: "Progress recorded for this run."

  defp event_label(kind) when is_binary(kind) do
    kind
    |> String.replace(".", " ")
    |> status_label()
  end

  defp event_label(_kind), do: "Event"

  defp attestation_label("local_self_reported"), do: "Worker-reported proof"
  defp attestation_label("platform_observed"), do: "Regent-confirmed proof"
  defp attestation_label("external_attested"), do: "Outside proof"
  defp attestation_label(_level), do: "Proof attached"
end
