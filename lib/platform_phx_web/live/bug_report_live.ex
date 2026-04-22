defmodule PlatformPhxWeb.BugReportLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.OperatorReports

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    pagination = OperatorReports.list_bug_reports_page(1, @page_size)
    filters = default_filters()

    {:ok,
     socket
     |> assign(:page_title, "Bug report ledger")
     |> assign(:filters, filters)
     |> assign(:filter_form, filters_form(filters))
     |> assign(:loaded_page, 1)
     |> assign(:next_page, 2)
     |> assign(:has_next, pagination.has_next)
     |> assign(:now, DateTime.utc_now())
     |> refresh_visible_reports(nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load-more", _params, %{assigns: %{has_next: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("load-more", _params, socket) do
    pagination = OperatorReports.list_bug_reports_page(socket.assigns.next_page, @page_size)

    {:noreply,
     socket
     |> assign(:loaded_page, socket.assigns.loaded_page + 1)
     |> assign(:next_page, socket.assigns.next_page + 1)
     |> assign(:has_next, pagination.has_next)
     |> assign(:now, DateTime.utc_now())
     |> refresh_visible_reports(socket.assigns.expanded_report_id)}
  end

  def handle_event("change-filters", %{"filters" => filter_params}, socket) do
    filters = normalize_filters(filter_params)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, filters_form(filters))
     |> assign(:now, DateTime.utc_now())
     |> refresh_visible_reports(nil)}
  end

  def handle_event("reset-filters", _params, socket) do
    filters = default_filters()

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, filters_form(filters))
     |> assign(:now, DateTime.utc_now())
     |> refresh_visible_reports(nil)}
  end

  def handle_event("toggle-report", %{"report-id" => report_id}, socket) do
    expanded_report_id =
      case Integer.parse(report_id) do
        {parsed_id, ""} ->
          if socket.assigns.expanded_report_id == parsed_id, do: nil, else: parsed_id

        _ ->
          socket.assigns.expanded_report_id
      end

    {:noreply, refresh_visible_reports(socket, expanded_report_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={assigns[:current_scope]}
      current_human={assigns[:current_human]}
      chrome={:app}
      active_nav="bug-report"
      header_eyebrow="Bug reports"
      header_title="Bug report ledger"
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-bug-report-shell"
        class="rg-regent-theme-platform space-y-6"
        phx-hook="BugReportReveal"
      >
        <section
          id="platform-bug-ledger-root"
          data-bug-ledger-block
          phx-hook="BugReportLedger"
          class="space-y-6"
        >
          <div
            data-bridge-block
            class="grid gap-6 rounded-[2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6 xl:grid-cols-[minmax(0,1fr)_minmax(24rem,40rem)]"
          >
            <div class="space-y-4">
              <h2 class="font-display text-[clamp(2.4rem,4vw,3.6rem)] leading-[0.9] tracking-[-0.06em] text-[color:var(--foreground)]">
                Bug reports and their current status
              </h2>
              <div class="max-w-[46rem] space-y-2 text-[1.05rem] leading-8 text-[color:color-mix(in_oklch,var(--foreground)_74%,var(--muted-foreground)_26%)]">
                <p>Issues reported by agents using Techtree, Autolaunch, and the CLI.</p>
                <p>Newest reports appear first so operators can act quickly.</p>
              </div>
            </div>

            <div id="platform-bug-ledger-summary" class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              <%= for card <- summary_cards(@status_totals, @report_count) do %>
                <section class="rounded-[1.3rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] px-4 py-4">
                  <div class="flex items-start gap-3">
                    <div class={[
                      "flex size-11 shrink-0 items-center justify-center rounded-[1rem]",
                      card.icon_class
                    ]}>
                      <.icon name={card.icon} class="size-5" />
                    </div>
                    <div class="space-y-1">
                      <p class="text-[0.72rem] uppercase tracking-[0.24em] text-[color:var(--muted-foreground)]">
                        {card.label}
                      </p>
                      <p class="text-[2rem] leading-none tracking-[-0.06em] text-[color:var(--foreground)]">
                        {card.count}
                      </p>
                      <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                        {card.note}
                      </p>
                    </div>
                  </div>
                </section>
              <% end %>
            </div>
          </div>

          <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_18.5rem]" data-bridge-block>
            <div class="space-y-6">
              <section class="overflow-hidden rounded-[1.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)]">
                <div class="hidden grid-cols-[12rem_minmax(0,1fr)_8rem_7rem_9rem] gap-4 border-b border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] px-6 py-4 text-sm font-medium text-[color:var(--foreground)] lg:grid">
                  <span>Reporter</span>
                  <span>Summary</span>
                  <span>Status</span>
                  <span>Opened</span>
                  <span>Details</span>
                </div>

                <%= if @report_count == 0 do %>
                  <article id="platform-bug-ledger-empty" class="px-6 py-10">
                    <p class="text-[0.72rem] uppercase tracking-[0.36em] text-[color:var(--brand-ink)]">
                      Live board
                    </p>
                    <h3 class="mt-4 font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                      No reports match this view.
                    </h3>
                    <p class="mt-4 max-w-[34rem] text-sm leading-6 text-[color:var(--muted-foreground)]">
                      When a report arrives, this board shows who sent it, what happened, and the current status in one place.
                    </p>
                    <div class="mt-6 flex flex-wrap gap-3">
                      <.link navigate={~p"/cli"} class="pp-link-button pp-link-button-slim">
                        View CLI <span aria-hidden="true">→</span>
                      </.link>
                      <.link
                        navigate={~p"/docs"}
                        class="pp-link-button pp-link-button-ghost pp-link-button-slim"
                      >
                        Read Docs <span aria-hidden="true">→</span>
                      </.link>
                    </div>
                  </article>
                <% else %>
                  <div id="platform-bug-ledger-table" class="overflow-x-auto">
                    <div id="platform-bug-ledger-stream" phx-update="stream">
                      <article
                        :for={{dom_id, report} <- @streams.reports}
                        id={dom_id}
                        class={[
                          "grid gap-4 border-b border-[color:color-mix(in_oklch,var(--border)_82%,transparent)] px-6 py-4 lg:grid-cols-[12rem_minmax(0,1fr)_8rem_7rem_9rem] lg:items-center",
                          @expanded_report_id == report.id &&
                            "bg-[color:color-mix(in_oklch,var(--brand-ink)_4%,var(--background)_96%)]"
                        ]}
                      >
                        <div class="flex items-start gap-3" data-label="Reporter">
                          <div class={[
                            "flex size-11 shrink-0 items-center justify-center rounded-[0.95rem] text-white",
                            source_chip_classes(report)
                          ]}>
                            <.icon name={source_icon(report)} class="size-5" />
                          </div>
                          <div class="min-w-0 space-y-1">
                            <p class="truncate text-sm font-medium text-[color:var(--foreground)]">
                              {reporter_title(report)}
                            </p>
                            <p class="truncate text-xs leading-5 text-[color:var(--muted-foreground)]">
                              {reporter_subtitle(report)}
                            </p>
                          </div>
                        </div>

                        <div class="space-y-2" data-label="Summary">
                          <p class="text-sm text-[color:var(--foreground)]">{report.summary}</p>
                          <div class="flex flex-wrap items-center gap-2">
                            <span class={[
                              "inline-flex items-center rounded-full px-2.5 py-1 text-[0.72rem]",
                              source_badge_classes(report)
                            ]}>
                              {inferred_source(report)}
                            </span>
                          </div>
                        </div>

                        <div data-label="Status">
                          <span class={[
                            "inline-flex rounded-full px-2.5 py-1 text-[0.72rem]",
                            status_class(report.status)
                          ]}>
                            {status_label(report.status)}
                          </span>
                        </div>

                        <div class="space-y-1" data-label="Opened">
                          <p class="text-sm text-[color:var(--foreground)]">
                            {relative_time(report, @now)}
                          </p>
                          <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                            {format_date(report.created_at)}
                          </p>
                        </div>

                        <div data-label="Details">
                          <button
                            type="button"
                            phx-click="toggle-report"
                            phx-value-report-id={report.id}
                            class="inline-flex w-full items-center justify-between rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                            aria-expanded={to_string(@expanded_report_id == report.id)}
                            aria-controls="platform-bug-ledger-details"
                          >
                            <span>Show details</span>
                            <span aria-hidden="true">
                              {if @expanded_report_id == report.id, do: "↑", else: "→"}
                            </span>
                          </button>
                        </div>
                      </article>
                    </div>
                  </div>
                <% end %>
              </section>

              <%= if @expanded_report do %>
                <section
                  id="platform-bug-ledger-details"
                  class="rounded-[1.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-6"
                >
                  <div class="flex flex-wrap items-start justify-between gap-4">
                    <div class="flex items-start gap-4">
                      <div class={[
                        "flex size-12 shrink-0 items-center justify-center rounded-[1rem] text-white",
                        detail_icon_class(@expanded_report)
                      ]}>
                        <.icon name={detail_icon(@expanded_report)} class="size-5" />
                      </div>
                      <div class="space-y-2">
                        <h3 class="font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
                          {@expanded_report.summary}
                        </h3>
                        <p class="text-sm leading-6 text-[color:var(--muted-foreground)]">
                          ID: {@expanded_report.report_id}
                          <span class="px-2">•</span>
                          Opened {format_datetime(@expanded_report.created_at)}
                        </p>
                      </div>
                    </div>

                    <span class={[
                      "inline-flex rounded-full px-2.5 py-1 text-[0.72rem]",
                      status_class(@expanded_report.status)
                    ]}>
                      {status_label(@expanded_report.status)}
                    </span>
                  </div>

                  <div class="mt-6 grid gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(18rem,0.85fr)]">
                    <div class="rounded-[1.2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-5 py-5">
                      <p class="text-sm font-medium text-[color:var(--foreground)]">Description</p>
                      <pre class="mt-4 whitespace-pre-wrap break-words text-sm leading-7 text-[color:var(--foreground)]">{@expanded_report.details}</pre>
                    </div>

                    <div class="space-y-4">
                      <section class="rounded-[1.2rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_94%,var(--card)_6%)] px-5 py-5">
                        <div class="flex items-start gap-3">
                          <div class={[
                            "flex size-11 shrink-0 items-center justify-center rounded-[0.95rem] text-white",
                            source_chip_classes(@expanded_report)
                          ]}>
                            <.icon name={source_icon(@expanded_report)} class="size-5" />
                          </div>
                          <div class="space-y-1">
                            <p class="text-sm font-medium text-[color:var(--foreground)]">
                              {reporter_title(@expanded_report)}
                            </p>
                            <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                              {reporter_subtitle(@expanded_report)}
                            </p>
                          </div>
                        </div>

                        <dl class="mt-5 grid gap-3 text-sm">
                          <div class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
                            <dt class="text-[color:var(--muted-foreground)]">Source</dt>
                            <dd class="text-[color:var(--foreground)]">
                              {inferred_source(@expanded_report)}
                            </dd>
                          </div>
                          <div class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
                            <dt class="text-[color:var(--muted-foreground)]">Wallet</dt>
                            <dd class="break-all text-[color:var(--foreground)]">
                              {reporter_wallet(@expanded_report)}
                            </dd>
                          </div>
                          <div class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
                            <dt class="text-[color:var(--muted-foreground)]">Registry</dt>
                            <dd class="break-all text-[color:var(--foreground)]">
                              {reporter_registry(@expanded_report)}
                            </dd>
                          </div>
                          <div class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
                            <dt class="text-[color:var(--muted-foreground)]">Token</dt>
                            <dd class="text-[color:var(--foreground)]">
                              {reporter_token(@expanded_report)}
                            </dd>
                          </div>
                        </dl>

                        <div class="mt-5 flex justify-end">
                          <button
                            id={"platform-bug-ledger-copy-#{@expanded_report.report_id}"}
                            type="button"
                            phx-hook="ClipboardCopy"
                            class="inline-flex items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                            aria-label={"Copy details for #{@expanded_report.report_id}"}
                            title={"Copy details for #{@expanded_report.report_id}"}
                            data-copy-text={@expanded_report.details}
                          >
                            <span>Copy details</span>
                            <.icon name="hero-document-duplicate" class="size-4" />
                          </button>
                        </div>
                      </section>
                    </div>
                  </div>
                </section>
              <% end %>

              <div class="flex items-center justify-between rounded-[1.5rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-6 py-4">
                <p class="text-sm text-[color:var(--muted-foreground)]">
                  Showing newest {Integer.to_string(@report_count)} reports in this view
                </p>
                <button
                  :if={@has_next}
                  id="bug-report-load-more"
                  type="button"
                  phx-click="load-more"
                  class="inline-flex items-center gap-2 rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--brand-ink)] transition duration-200 hover:border-[color:var(--ring)]"
                >
                  <.icon name="hero-arrow-down" class="size-4" />
                  <span>Load more reports</span>
                </button>
              </div>
            </div>

            <div class="space-y-6">
              <section class="rounded-[1.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-5 py-5">
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-[0.95rem] bg-[color:color-mix(in_oklch,var(--foreground)_8%,var(--background)_92%)] text-[color:var(--foreground)]">
                    <.icon name="hero-funnel" class="size-4" />
                  </div>
                  <h3 class="text-[1.05rem] font-medium text-[color:var(--foreground)]">Filters</h3>
                </div>

                <.form
                  for={@filter_form}
                  id="bug-report-filters"
                  phx-change="change-filters"
                  class="mt-5 space-y-4"
                >
                  <.input
                    field={@filter_form[:status]}
                    type="select"
                    label="Status"
                    options={status_options()}
                  />
                  <.input
                    field={@filter_form[:source]}
                    type="select"
                    label="Source"
                    options={source_options()}
                  />
                  <.input
                    field={@filter_form[:reporter]}
                    type="select"
                    label="Reporter"
                    options={reporter_options()}
                  />
                  <.input
                    field={@filter_form[:time_window]}
                    type="select"
                    label="Time"
                    options={time_options()}
                  />
                </.form>

                <button
                  type="button"
                  phx-click="reset-filters"
                  class="mt-4 inline-flex w-full items-center justify-center rounded-[0.95rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:var(--background)] px-4 py-3 text-sm text-[color:var(--foreground)] transition duration-200 hover:border-[color:var(--ring)]"
                >
                  Reset filters
                </button>
              </section>

              <section class="rounded-[1.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-5 py-5">
                <h3 class="text-[1.05rem] font-medium text-[color:var(--foreground)]">
                  System summary
                </h3>
                <dl class="mt-4 space-y-3 text-sm">
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-[color:var(--muted-foreground)]">Reports today</dt>
                    <dd class="text-[color:var(--foreground)]">
                      {reports_today(@visible_reports, @now)}
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-[color:var(--muted-foreground)]">Open requiring attention</dt>
                    <dd class="text-[color:#d33b35]">{Map.get(@status_totals, "pending", 0)}</dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-[color:var(--muted-foreground)]">Resolved</dt>
                    <dd class="text-[color:#1a915b]">{Map.get(@status_totals, "fixed", 0)}</dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-[color:var(--muted-foreground)]">Median time shown</dt>
                    <dd class="text-[color:var(--foreground)]">
                      {median_age_label(@visible_reports, @now)}
                    </dd>
                  </div>
                </dl>
              </section>

              <section class="rounded-[1.85rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_98%,var(--card)_2%)] px-5 py-5">
                <h3 class="text-[1.05rem] font-medium text-[color:var(--foreground)]">Integration</h3>
                <p class="mt-2 text-sm leading-6 text-[color:var(--muted-foreground)]">
                  Reports are generated by agents using:
                </p>
                <div class="mt-4 space-y-3">
                  <%= for source <- ["Techtree", "Autolaunch", "CLI"] do %>
                    <div class="flex items-center justify-between gap-3 rounded-[1rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_92%,var(--card)_8%)] px-4 py-3">
                      <div class="flex items-center gap-3">
                        <div class={[
                          "flex size-10 items-center justify-center rounded-[0.9rem] text-white",
                          source_chip_classes(source)
                        ]}>
                          <.icon name={source_icon(source)} class="size-4" />
                        </div>
                        <div>
                          <p class="text-sm text-[color:var(--foreground)]">{source}</p>
                          <p class="text-xs leading-5 text-[color:var(--muted-foreground)]">
                            {Map.get(@source_totals, source, 0)} reports loaded
                          </p>
                        </div>
                      </div>
                      <span class={[
                        "inline-flex rounded-full px-2.5 py-1 text-[0.72rem]",
                        if(Map.get(@source_totals, source, 0) > 0,
                          do: "bg-[color:rgba(34,197,94,0.12)] text-[color:#1f9250]",
                          else:
                            "bg-[color:rgba(148,163,184,0.12)] text-[color:var(--muted-foreground)]"
                        )
                      ]}>
                        {if Map.get(@source_totals, source, 0) > 0, do: "Active", else: "Quiet"}
                      </span>
                    </div>
                  <% end %>
                </div>
              </section>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp refresh_visible_reports(socket, expanded_report_id) do
    loaded_reports = loaded_reports(socket.assigns.loaded_page)

    visible_reports =
      apply_filters(loaded_reports, socket.assigns.filters, socket.assigns.now)

    expanded_report = expanded_report(visible_reports, expanded_report_id)
    status_totals = status_totals(visible_reports)
    source_totals = source_totals(visible_reports)

    socket
    |> assign(:visible_reports, visible_reports)
    |> assign(:report_count, length(visible_reports))
    |> assign(:status_totals, status_totals)
    |> assign(:source_totals, source_totals)
    |> assign(:expanded_report_id, expanded_report && expanded_report.id)
    |> assign(:expanded_report, expanded_report)
    |> stream(:reports, visible_reports, reset: true)
  end

  defp loaded_reports(loaded_page) when is_integer(loaded_page) and loaded_page > 0 do
    1..loaded_page
    |> Enum.flat_map(fn page ->
      OperatorReports.list_bug_reports_page(page, @page_size).entries
    end)
  end

  defp loaded_reports(_loaded_page), do: []

  defp expanded_report([], _expanded_report_id), do: nil

  defp expanded_report(visible_reports, nil), do: List.first(visible_reports)

  defp expanded_report(visible_reports, expanded_report_id) do
    Enum.find(visible_reports, List.first(visible_reports), &(&1.id == expanded_report_id))
  end

  defp apply_filters(reports, filters, now) do
    Enum.filter(reports, fn report ->
      matches_status?(report, filters["status"]) and
        matches_source?(report, filters["source"]) and
        matches_reporter?(report, filters["reporter"]) and
        matches_time_window?(report, filters["time_window"], now)
    end)
  end

  defp default_filters do
    %{
      "status" => "all",
      "source" => "all",
      "reporter" => "all",
      "time_window" => "all"
    }
  end

  defp normalize_filters(params) when is_map(params) do
    default_filters()
    |> Map.merge(Map.take(params, ["status", "source", "reporter", "time_window"]))
  end

  defp normalize_filters(_params), do: default_filters()

  defp filters_form(filters), do: to_form(filters, as: :filters)

  defp status_options do
    [
      {"All status", "all"},
      {"Open", "pending"},
      {"Resolved", "fixed"},
      {"Not planned", "won't fix"},
      {"Duplicate", "duplicate"}
    ]
  end

  defp source_options do
    [
      {"All sources", "all"},
      {"Techtree", "Techtree"},
      {"Autolaunch", "Autolaunch"},
      {"CLI", "CLI"},
      {"Website", "Website"}
    ]
  end

  defp reporter_options do
    [
      {"All reporters", "all"},
      {"Wallet-backed", "wallet"},
      {"Public form", "public"}
    ]
  end

  defp time_options do
    [
      {"All time", "all"},
      {"Last 24 hours", "24h"},
      {"Last 7 days", "7d"},
      {"Last 30 days", "30d"}
    ]
  end

  defp matches_status?(_report, "all"), do: true
  defp matches_status?(report, status), do: report.status == status

  defp matches_source?(_report, "all"), do: true
  defp matches_source?(report, source), do: inferred_source(report) == source

  defp matches_reporter?(_report, "all"), do: true
  defp matches_reporter?(report, "wallet"), do: present?(report.reporter_wallet_address)
  defp matches_reporter?(report, "public"), do: not present?(report.reporter_wallet_address)
  defp matches_reporter?(_report, _other), do: true

  defp matches_time_window?(_report, "all", _now), do: true

  defp matches_time_window?(report, time_window, now) do
    seconds =
      case time_window do
        "24h" -> 24 * 60 * 60
        "7d" -> 7 * 24 * 60 * 60
        "30d" -> 30 * 24 * 60 * 60
        _ -> nil
      end

    case {seconds, report.created_at} do
      {nil, _} -> true
      {_, nil} -> false
      {limit, created_at} -> DateTime.diff(now, created_at, :second) <= limit
    end
  end

  defp reporter_title(report) do
    cond do
      present?(report.reporter_label) ->
        report.reporter_label

      present?(report.reporter_registry_address) and present?(report.reporter_token_id) ->
        "Wallet-backed agent"

      present?(report.reporter_wallet_address) ->
        "Signed agent report"

      true ->
        "Anonymous public report"
    end
  end

  defp reporter_subtitle(report) do
    cond do
      present?(report.reporter_wallet_address) ->
        abbreviated_wallet(report.reporter_wallet_address)

      true ->
        "Sent from the public bug report form"
    end
  end

  defp reporter_wallet(report) do
    report.reporter_wallet_address || "No wallet attached"
  end

  defp reporter_registry(report) do
    report.reporter_registry_address || "No registry address"
  end

  defp reporter_token(report) do
    report.reporter_token_id || "No token id"
  end

  defp abbreviated_wallet(nil), do: "No wallet attached"

  defp abbreviated_wallet(wallet_address) when is_binary(wallet_address) do
    if String.length(wallet_address) <= 10 do
      wallet_address
    else
      "#{String.slice(wallet_address, 0, 6)}...#{String.slice(wallet_address, -4, 4)}"
    end
  end

  defp inferred_source(report) do
    text =
      [
        report.reporter_label,
        report.summary,
        report.details
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")
      |> String.downcase()

    cond do
      String.contains?(text, "autolaunch") -> "Autolaunch"
      String.contains?(text, "cli") -> "CLI"
      String.contains?(text, "techtree") -> "Techtree"
      true -> "Website"
    end
  end

  defp source_totals(reports) do
    Enum.reduce(reports, %{}, fn report, totals ->
      Map.update(totals, inferred_source(report), 1, &(&1 + 1))
    end)
  end

  defp source_icon(report) when is_map(report), do: source_icon(inferred_source(report))
  defp source_icon("Techtree"), do: "hero-sparkles"
  defp source_icon("Autolaunch"), do: "hero-rocket-launch"
  defp source_icon("CLI"), do: "hero-command-line"
  defp source_icon(_source), do: "hero-globe-alt"

  defp source_chip_classes(report) when is_map(report),
    do: source_chip_classes(inferred_source(report))

  defp source_chip_classes("Techtree"), do: "bg-[linear-gradient(180deg,#1e57d6,#133f9f)]"
  defp source_chip_classes("Autolaunch"), do: "bg-[linear-gradient(180deg,#22b8cf,#16879a)]"
  defp source_chip_classes("CLI"), do: "bg-[linear-gradient(180deg,#182847,#0d1730)]"
  defp source_chip_classes(_source), do: "bg-[linear-gradient(180deg,#64748b,#475569)]"

  defp source_badge_classes(report) do
    case inferred_source(report) do
      "Techtree" -> "bg-[color:rgba(30,87,214,0.1)] text-[color:#1e57d6]"
      "Autolaunch" -> "bg-[color:rgba(34,184,207,0.12)] text-[color:#16879a]"
      "CLI" -> "bg-[color:rgba(15,27,53,0.12)] text-[color:#0f1b35]"
      _ -> "bg-[color:rgba(100,116,139,0.12)] text-[color:#475569]"
    end
  end

  defp detail_icon(report) do
    case report.status do
      "fixed" -> "hero-check-circle"
      "won't fix" -> "hero-no-symbol"
      "duplicate" -> "hero-squares-2x2"
      _ -> "hero-bug-ant"
    end
  end

  defp detail_icon_class(report) do
    case report.status do
      "fixed" -> "bg-[linear-gradient(180deg,#22c55e,#15803d)]"
      "won't fix" -> "bg-[linear-gradient(180deg,#f59e0b,#d97706)]"
      "duplicate" -> "bg-[linear-gradient(180deg,#64748b,#475569)]"
      _ -> "bg-[linear-gradient(180deg,#ef4444,#dc2626)]"
    end
  end

  defp summary_cards(status_totals, report_count) do
    [
      %{
        label: "Open",
        count: Map.get(status_totals, "pending", 0),
        note: "Needs attention",
        icon: "hero-bug-ant",
        icon_class: "bg-[color:rgba(239,68,68,0.12)] text-[color:#d33b35]"
      },
      %{
        label: "Resolved",
        count: Map.get(status_totals, "fixed", 0),
        note: "Completed",
        icon: "hero-check-circle",
        icon_class: "bg-[color:rgba(34,197,94,0.12)] text-[color:#1a915b]"
      },
      %{
        label: "Not planned",
        count: Map.get(status_totals, "won't fix", 0),
        note: "Closed without a change",
        icon: "hero-no-symbol",
        icon_class: "bg-[color:rgba(245,158,11,0.12)] text-[color:#d97706]"
      },
      %{
        label: "Visible now",
        count: report_count,
        note: "Current view",
        icon: "hero-users",
        icon_class: "bg-[color:rgba(15,27,53,0.08)] text-[color:#0f1b35]"
      }
    ]
  end

  defp reports_today(reports, now) do
    Enum.count(reports, fn report ->
      match?(true, matches_time_window?(report, "24h", now))
    end)
  end

  defp median_age_label([], _now), do: "0m"

  defp median_age_label(reports, now) do
    seconds =
      reports
      |> Enum.map(fn report ->
        case report.created_at do
          %DateTime{} = created_at -> DateTime.diff(now, created_at, :second)
          _ -> 0
        end
      end)
      |> Enum.sort()

    seconds
    |> Enum.at(div(length(seconds), 2), 0)
    |> duration_label()
  end

  defp relative_time(report, now) do
    case report.created_at do
      %DateTime{} = created_at -> duration_label(DateTime.diff(now, created_at, :second))
      _ -> "Unknown"
    end
  end

  defp duration_label(seconds) when seconds < 60, do: "#{seconds}s ago"
  defp duration_label(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m ago"
  defp duration_label(seconds) when seconds < 86_400, do: "#{div(seconds, 3600)}h ago"
  defp duration_label(seconds), do: "#{div(seconds, 86_400)}d ago"

  defp format_date(nil), do: "Unknown date"
  defp format_date(%DateTime{} = value), do: Calendar.strftime(value, "%b %d")

  defp format_datetime(nil), do: "Unknown time"
  defp format_datetime(%DateTime{} = value), do: Calendar.strftime(value, "%b %d, %Y %H:%M UTC")

  defp status_totals(reports) do
    Enum.reduce(reports, %{}, fn report, totals ->
      Map.update(totals, report.status, 1, &(&1 + 1))
    end)
  end

  defp status_label("pending"), do: "Open"
  defp status_label("fixed"), do: "Resolved"
  defp status_label("won't fix"), do: "Not planned"
  defp status_label("duplicate"), do: "Duplicate"
  defp status_label(_status), do: "Open"

  defp status_class("pending"), do: "bg-[color:rgba(239,68,68,0.12)] text-[color:#d33b35]"
  defp status_class("fixed"), do: "bg-[color:rgba(34,197,94,0.12)] text-[color:#1a915b]"
  defp status_class("won't fix"), do: "bg-[color:rgba(245,158,11,0.12)] text-[color:#d97706]"
  defp status_class("duplicate"), do: "bg-[color:rgba(100,116,139,0.12)] text-[color:#475569]"
  defp status_class(_status), do: "bg-[color:rgba(239,68,68,0.12)] text-[color:#d33b35]"

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
