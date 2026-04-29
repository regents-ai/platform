defmodule PlatformPhxWeb.App.RuntimesLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Companies
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.RuntimeRegistry
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
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
  def handle_event("pause_runtime", %{"runtime_id" => runtime_id}, socket) do
    change_runtime_status(socket, runtime_id, "paused", "Runtime paused.")
  end

  @impl true
  def handle_event("resume_runtime", %{"runtime_id" => runtime_id}, socket) do
    change_runtime_status(socket, runtime_id, "active", "Runtime running again.")
  end

  @impl true
  def handle_event("checkpoint_runtime", %{"runtime_id" => runtime_id}, socket) do
    with %RuntimeProfile{} = runtime <- owned_runtime(socket, runtime_id),
         {:ok, _checkpoint} <- create_checkpoint(runtime) do
      {:noreply,
       socket
       |> put_flash(:info, checkpoint_message(runtime))
       |> load_payload(socket.assigns.params)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Checkpoint could not be saved.")}
    end
  end

  @impl true
  def handle_event(
        "restore_runtime",
        %{"runtime_id" => runtime_id, "checkpoint_id" => checkpoint_id},
        socket
      ) do
    with %RuntimeProfile{} = runtime <- owned_runtime(socket, runtime_id),
         checkpoint when not is_nil(checkpoint) <-
           owned_checkpoint(socket, runtime.id, checkpoint_id),
         {:ok, _checkpoint} <- RuntimeRegistry.request_hosted_sprite_restore(runtime, checkpoint) do
      {:noreply,
       socket
       |> put_flash(:info, "Restore requested.")
       |> load_payload(socket.assigns.params)}
    else
      _error ->
        {:noreply, put_flash(socket, :error, "Restore could not be requested.")}
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
                      <.fact label="Capacity" value={capacity_summary(runtime, @usage_by_runtime)} />
                    </div>
                  </div>

                  <div class="mt-5 flex flex-wrap gap-2">
                    <button
                      type="button"
                      phx-click="checkpoint_runtime"
                      phx-value-runtime_id={runtime.id}
                      class="rounded-md border border-[color:var(--foreground)] bg-[color:var(--foreground)] px-3 py-2 text-[0.86rem] text-[color:var(--background)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                    >
                      Save checkpoint
                    </button>
                    <button
                      :if={runtime.status == "active"}
                      type="button"
                      phx-click="pause_runtime"
                      phx-value-runtime_id={runtime.id}
                      class="rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.86rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                    >
                      Pause
                    </button>
                    <button
                      :if={runtime.status == "paused"}
                      type="button"
                      phx-click="resume_runtime"
                      phx-value-runtime_id={runtime.id}
                      class="rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.86rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                    >
                      Resume
                    </button>
                    <.link
                      :if={present?(runtime.rate_limit_upgrade_url)}
                      href={runtime.rate_limit_upgrade_url}
                      class="rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.86rem] text-[color:var(--link-color)] underline decoration-[color:var(--link-underline)] underline-offset-4 transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                    >
                      Upgrade capacity
                    </.link>
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
                        class="mt-3 border-t border-[color:var(--border)] pt-3 text-[0.9rem]"
                      >
                        <div class="flex items-center justify-between gap-3">
                          <span class="text-[color:var(--foreground)]">{service.name}</span>
                          <span class="text-[color:var(--muted-foreground)]">
                            {service_health_label(service)}
                          </span>
                        </div>
                        <p class="mt-1 text-[0.82rem] text-[color:var(--muted-foreground)]">
                          Checked {time_label(service.status_observed_at)}
                        </p>
                        <p
                          :if={present?(service.last_log_excerpt) || present?(service.log_cursor)}
                          class="mt-1 line-clamp-2 text-[0.82rem] leading-6 text-[color:var(--muted-foreground)]"
                        >
                          Latest note: {service_log_label(service)}
                        </p>
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
                        class="mt-3 border-t border-[color:var(--border)] pt-3 text-[0.9rem]"
                      >
                        <div class="flex items-center justify-between gap-3">
                          <span class="truncate text-[color:var(--foreground)]">
                            {checkpoint.checkpoint_ref}
                          </span>
                          <span class="shrink-0 text-[color:var(--muted-foreground)]">
                            {checkpoint_restore_label(checkpoint)}
                          </span>
                        </div>
                        <p class="mt-1 text-[0.82rem] text-[color:var(--muted-foreground)]">
                          Saved {time_label(checkpoint.captured_at || checkpoint.updated_at)}
                        </p>
                        <button
                          :if={can_restore?(@runtime_by_id, checkpoint)}
                          type="button"
                          phx-click="restore_runtime"
                          phx-value-runtime_id={checkpoint.runtime_profile_id}
                          phx-value-checkpoint_id={checkpoint.id}
                          class="mt-3 rounded-md border border-[color:var(--border)] px-3 py-2 text-[0.84rem] text-[color:var(--foreground)] transition duration-150 ease-[var(--ease-out-quart)] active:scale-[0.98]"
                        >
                          Restore
                        </button>
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
    companies = Companies.list_owned_companies(socket.assigns.current_human)
    company = selected_company(companies, params)

    runtimes = runtimes(company)
    services = records_by_runtime(services(company))
    checkpoints = records_by_runtime(checkpoints(company))
    usage = records_by_runtime(usage(company))

    socket
    |> assign(:companies, companies)
    |> assign(:company, company)
    |> assign(:params, params)
    |> assign(:runtimes, runtimes)
    |> assign(:runtime_by_id, Map.new(runtimes, &{&1.id, &1}))
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

  defp capacity_summary(runtime, usage_by_runtime) do
    memory =
      runtime.observed_memory_mb || latest_value(runtime, usage_by_runtime, :reported_memory_mb)

    storage =
      runtime.observed_storage_bytes ||
        latest_value(runtime, usage_by_runtime, :reported_storage_bytes)

    case {memory, storage} do
      {nil, nil} -> "Not observed yet"
      {nil, storage} -> storage_label(storage)
      {memory, nil} -> "#{memory} MB memory"
      {memory, storage} -> "#{memory} MB, #{storage_label(storage)}"
    end
  end

  defp latest_value(runtime, usage_by_runtime, field) do
    usage_by_runtime
    |> Map.get(runtime.id, [])
    |> List.first()
    |> case do
      nil -> nil
      snapshot -> Map.get(snapshot, field)
    end
  end

  defp storage_label(nil), do: nil

  defp storage_label(bytes) when bytes >= 1_000_000_000 do
    "#{Float.round(bytes / 1_000_000_000, 1)} GB storage"
  end

  defp storage_label(bytes) when bytes >= 1_000_000 do
    "#{Float.round(bytes / 1_000_000, 1)} MB storage"
  end

  defp storage_label(bytes), do: "#{bytes} B storage"

  defp service_health_label(%{status: status}), do: status_label(status)

  defp service_log_label(%{last_log_excerpt: excerpt}) when is_binary(excerpt) and excerpt != "",
    do: excerpt

  defp service_log_label(%{log_cursor: cursor}) when is_binary(cursor) and cursor != "",
    do: "New updates available"

  defp service_log_label(_service), do: "No note yet"

  defp checkpoint_restore_label(%{restore_status: status})
       when is_binary(status) and status != "",
       do: "Restore #{status_label(status) |> String.downcase()}"

  defp checkpoint_restore_label(%{status: status}), do: status_label(status)

  defp owned_runtime(socket, runtime_id) do
    case socket.assigns.company do
      nil -> nil
      company -> RuntimeRegistry.get_runtime_profile(company.id, parse_id(runtime_id))
    end
  end

  defp owned_checkpoint(socket, runtime_id, checkpoint_id) do
    socket.assigns.checkpoints_by_runtime
    |> Map.get(runtime_id, [])
    |> Enum.find(&(to_string(&1.id) == to_string(checkpoint_id)))
  end

  defp create_checkpoint(%RuntimeProfile{} = runtime) do
    attrs = %{
      company_id: runtime.company_id,
      runtime_profile_id: runtime.id,
      checkpoint_ref: checkpoint_ref(runtime),
      status: "ready",
      captured_at: PlatformPhx.Clock.now()
    }

    if hosted_sprite_runtime?(runtime) do
      RuntimeRegistry.create_hosted_sprite_checkpoint(runtime, attrs)
    else
      RuntimeRegistry.create_runtime_checkpoint(attrs)
    end
  end

  defp checkpoint_message(%RuntimeProfile{} = runtime) do
    if hosted_sprite_runtime?(runtime), do: "Checkpoint requested.", else: "Checkpoint saved."
  end

  defp checkpoint_ref(%RuntimeProfile{id: id}) do
    timestamp =
      PlatformPhx.Clock.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_unix()

    "checkpoint-#{id}-#{timestamp}"
  end

  defp change_runtime_status(socket, runtime_id, status, message) do
    with %RuntimeProfile{} = runtime <- owned_runtime(socket, runtime_id),
         :ok <- change_hosted_runtime_state(runtime, status, socket.assigns.current_human),
         {:ok, _runtime} <- RuntimeRegistry.update_runtime_profile_status(runtime, status) do
      {:noreply,
       socket
       |> put_flash(:info, message)
       |> load_payload(socket.assigns.params)}
    else
      _error -> {:noreply, put_flash(socket, :error, "Runtime status could not be changed.")}
    end
  end

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _other -> value
    end
  end

  defp parse_id(value), do: value

  defp hosted_sprite_runtime?(%RuntimeProfile{
         execution_surface: "hosted_sprite",
         billing_mode: "platform_hosted",
         platform_agent: %Agent{}
       }),
       do: true

  defp hosted_sprite_runtime?(_runtime), do: false

  defp can_restore?(runtime_by_id, checkpoint) do
    runtime_by_id
    |> Map.get(checkpoint.runtime_profile_id)
    |> hosted_sprite_runtime?() and checkpoint.status == "ready" and
      checkpoint.restore_status not in ["pending", "succeeded"]
  end

  defp change_hosted_runtime_state(
         %RuntimeProfile{platform_agent: %Agent{} = agent} = runtime,
         "paused",
         human
       )
       when runtime.execution_surface == "hosted_sprite" and
              runtime.billing_mode == "platform_hosted" do
    with {:ok, _agent} <-
           RuntimeControl.pause(agent,
             actor_type: "human",
             human_user_id: human && human.id,
             source: "rwr_app"
           ) do
      :ok
    end
  end

  defp change_hosted_runtime_state(
         %RuntimeProfile{platform_agent: %Agent{} = agent} = runtime,
         "active",
         human
       )
       when runtime.execution_surface == "hosted_sprite" and
              runtime.billing_mode == "platform_hosted" do
    with {:ok, _agent} <-
           RuntimeControl.resume(agent,
             actor_type: "human",
             human_user_id: human && human.id,
             source: "rwr_app"
           ) do
      :ok
    end
  end

  defp change_hosted_runtime_state(_runtime, _status, _human), do: :ok

  defp present?(value), do: is_binary(value) and value != ""
end
