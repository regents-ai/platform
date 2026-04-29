defmodule PlatformPhxWeb.App.RunLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.RunEvents
  alias PlatformPhx.WorkRuns
  alias PlatformPhx.WorkRuns.ApprovalRequest
  alias PlatformPhx.WorkRuns.WorkArtifact
  import PlatformPhxWeb.App.RwrComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Run")
     |> load_payload(id)}
  end

  @impl true
  def handle_event("publish_artifact", %{"artifact_id" => artifact_id}, socket) do
    with %WorkArtifact{} = artifact <- owned_artifact(socket, artifact_id),
         {:ok, _artifact} <- WorkRuns.publish_artifact(artifact) do
      {:noreply,
       socket
       |> put_flash(:info, "Proof published.")
       |> load_payload(socket.assigns.run_id)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Proof could not be published.")}
    end
  end

  @impl true
  def handle_event(
        "resolve_approval",
        %{"approval_id" => approval_id, "decision" => decision},
        socket
      ) do
    with %ApprovalRequest{} = approval <- owned_approval(socket, approval_id),
         {:ok, _approval} <-
           WorkRuns.resolve_approval_request(approval, %{
             status: decision,
             resolved_by_human_id: socket.assigns.current_human.id,
             resolved_at: PlatformPhx.Clock.now()
           }) do
      {:noreply,
       socket
       |> put_flash(:info, approval_message(decision))
       |> load_payload(socket.assigns.run_id)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Review could not be saved.")}
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
                  phx-click="publish_artifact"
                  phx-value-artifact_id={first_artifact_id(@artifacts)}
                  disabled={@artifacts == []}
                  class="rounded-md border border-[color:var(--border)] px-4 py-2 text-[0.9rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Publish this run
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
                      Run family
                    </p>
                  </div>
                  <div class="grid gap-3 px-4 py-4 sm:grid-cols-3">
                    <.fact label="Parent run" value={run_ref(@run.parent_run)} />
                    <.fact label="Root run" value={run_ref(@run.root_run)} />
                    <.fact label="Assigned by" value={run_ref(@run.delegated_by_run)} />
                  </div>
                  <div class="border-t border-[color:var(--border)] px-4 py-4">
                    <p class="text-[0.72rem] uppercase tracking-[0.08em] text-[color:var(--muted-foreground)]">
                      Full run tree
                    </p>
                    <div
                      :if={@run_tree == []}
                      class="mt-2 text-[0.9rem] text-[color:var(--muted-foreground)]"
                    >
                      No child runs yet.
                    </div>
                    <div
                      :for={tree_run <- @run_tree}
                      class="mt-3 grid gap-3 border-t border-[color:var(--border)] pt-3 sm:grid-cols-[minmax(0,1fr)_9rem_9rem] sm:items-center"
                    >
                      <div class="min-w-0" style={"padding-left: #{tree_run.depth * 1.25}rem"}>
                        <.link
                          navigate={~p"/app/runs/#{tree_run.run.id}"}
                          class="text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4"
                        >
                          {run_tree_title(tree_run.run)}
                        </.link>
                        <p class="mt-1 line-clamp-2 text-[0.82rem] leading-6 text-[color:var(--muted-foreground)]">
                          {tree_run.run.summary || "No summary yet."}
                        </p>
                      </div>
                      <span class="text-[0.88rem] text-[color:var(--muted-foreground)]">
                        {status_label(tree_run.run.status)}
                      </span>
                      <span class="text-[0.88rem] text-[color:var(--muted-foreground)] sm:text-right">
                        {completion_label(tree_run.run)}
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
                    <p
                      :if={present?(artifact.uri)}
                      class="mt-1 break-all text-[0.84rem] text-[color:var(--link-color)]"
                    >
                      {artifact.uri}
                    </p>
                    <p
                      :if={present?(artifact.digest)}
                      class="mt-1 break-all text-[0.84rem] text-[color:var(--muted-foreground)]"
                    >
                      Proof: {artifact.digest}
                    </p>
                    <button
                      type="button"
                      phx-click="publish_artifact"
                      phx-value-artifact_id={artifact.id}
                      disabled={artifact.visibility == "public"}
                      class="mt-3 rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.84rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      {if artifact.visibility == "public", do: "Published", else: "Publish proof"}
                    </button>
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
                    <p class="text-[color:var(--foreground)]">
                      {approval_label(approval)}
                    </p>
                    <p class="mt-1 text-[0.84rem] leading-6 text-[color:var(--muted-foreground)]">
                      {approval.risk_summary || "Approval request is waiting for review."}
                    </p>
                    <p class="mt-1 text-[0.84rem] text-[color:var(--muted-foreground)]">
                      {approval_timing_label(approval)}
                    </p>
                    <div :if={approval.status == "pending"} class="mt-3 flex flex-wrap gap-2">
                      <button
                        type="button"
                        phx-click="resolve_approval"
                        phx-value-approval_id={approval.id}
                        phx-value-decision="approved"
                        class="rounded-md border border-[color:var(--foreground)] bg-[color:var(--foreground)] px-3 py-2 text-[0.84rem] text-[color:var(--background)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        phx-click="resolve_approval"
                        phx-value-approval_id={approval.id}
                        phx-value-decision="denied"
                        class="rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.84rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                      >
                        Decline
                      </button>
                    </div>
                  </div>
                </section>

                <section class="border border-[color:var(--border)] px-4 py-4 text-[0.9rem] leading-7 text-[color:var(--muted-foreground)]">
                  Review the run, approve waiting requests, then publish proof when it is ready to share.
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
    |> assign(:run_id, id)
    |> assign(:run, run)
    |> assign(:children, children(run))
    |> assign(:run_tree, run_tree(run))
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

  defp run_tree(nil), do: []

  defp run_tree(run) do
    run.work_item_id
    |> List.wrap()
    |> WorkRuns.list_runs_for_work_items()
    |> Enum.filter(&same_family?(&1, run))
    |> flatten_tree(root_id(run))
  end

  defp same_family?(candidate, run) do
    root = root_id(run)

    candidate.id == root or
      candidate.root_run_id == root or
      candidate.parent_run_id == root or
      candidate.id == run.id
  end

  defp root_id(%{root_run_id: nil, id: id}), do: id
  defp root_id(%{root_run_id: root_id}), do: root_id

  defp flatten_tree(runs, root_id) do
    by_parent = Enum.group_by(runs, &(&1.parent_run_id || :root))
    roots = Enum.filter(Map.get(by_parent, :root, []), &(&1.id == root_id))

    roots
    |> Enum.flat_map(&flatten_tree_node(&1, by_parent, 0))
  end

  defp flatten_tree_node(run, by_parent, depth) do
    children =
      by_parent
      |> Map.get(run.id, [])
      |> Enum.sort_by(&{&1.created_at || &1.updated_at, &1.id})
      |> Enum.flat_map(&flatten_tree_node(&1, by_parent, depth + 1))

    [%{run: run, depth: depth} | children]
  end

  defp events(nil), do: []
  defp events(run), do: RunEvents.list_events(run.company_id, run.id)

  defp artifacts(nil), do: []
  defp artifacts(run), do: WorkRuns.list_artifacts(run.company_id, run.id)

  defp approvals(nil), do: []
  defp approvals(run), do: WorkRuns.list_approval_requests(run.company_id, run.id)

  defp owned_artifact(socket, artifact_id) do
    Enum.find(socket.assigns.artifacts, &(to_string(&1.id) == to_string(artifact_id)))
  end

  defp owned_approval(socket, approval_id) do
    Enum.find(socket.assigns.approvals, &(to_string(&1.id) == to_string(approval_id)))
  end

  defp first_artifact_id([artifact | _rest]), do: artifact.id
  defp first_artifact_id([]), do: nil

  defp run_ref(nil), do: "None"
  defp run_ref(%{id: id, status: status}), do: "Run #{id}, #{status_label(status)}"

  defp run_tree_title(run) do
    if run.parent_run_id do
      "Child run #{run.id}"
    else
      "Root run #{run.id}"
    end
  end

  defp completion_label(%{completed_at: %DateTime{} = at}), do: time_label(at)
  defp completion_label(%{status: "completed"}), do: "Completed"
  defp completion_label(_run), do: "Not finished"

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

  defp approval_label(%{status: status, kind: kind}) do
    "#{status_label(status)} #{approval_kind_label(kind)}"
  end

  defp approval_kind_label("protected_action"), do: "review"
  defp approval_kind_label(_kind), do: "approval"

  defp approval_timing_label(%{resolved_at: %DateTime{} = resolved_at}) do
    "Resolved #{time_label(resolved_at)}"
  end

  defp approval_timing_label(%{expires_at: %DateTime{} = expires_at}) do
    "Due #{time_label(expires_at)}"
  end

  defp approval_timing_label(_approval), do: "Waiting for an operator"

  defp approval_message("approved"), do: "Review approved."
  defp approval_message("denied"), do: "Review declined."
  defp approval_message(_decision), do: "Review saved."

  defp present?(value), do: is_binary(value) and value != ""
end
