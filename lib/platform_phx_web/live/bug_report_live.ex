defmodule PlatformPhxWeb.BugReportLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.OperatorReports
  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    pagination = OperatorReports.list_bug_reports_page(1, @page_size)

    {:ok,
     socket
     |> assign(:page_title, "Bug Report Ledger")
     |> assign(:report_count, length(pagination.entries))
     |> assign(:next_page, 2)
     |> assign(:has_next, pagination.has_next)
     |> stream(:reports, pagination.entries)}
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
     |> assign(:report_count, socket.assigns.report_count + length(pagination.entries))
     |> assign(:next_page, socket.assigns.next_page + 1)
     |> assign(:has_next, pagination.has_next)
     |> stream(:reports, pagination.entries)}
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
      theme_class="rg-regent-theme-platform"
    >
      <div
        id="platform-bug-report-shell"
        class="pp-route-shell rg-regent-theme-platform"
        phx-hook="BugReportReveal"
      >
        <div class="pp-route-stage">
          <section
            id="platform-bug-ledger-root"
            class="pp-bug-ledger-shell"
            data-bug-ledger-block
            phx-hook="BugReportLedger"
          >
            <header class="pp-bug-ledger-header">
              <div class="pp-bug-ledger-header-copy">
                <p class="pp-home-kicker">Operator Ledger</p>
                <h2 class="pp-route-panel-title">Bug reports and their current status</h2>
                <p class="pp-panel-copy">
                  Reports sent from agents using Techtree, Autolaunch, and the CLI appear here newest first, so summaries stay concise while the details drawer holds the full plain-text report.
                </p>
              </div>
            </header>

            <%= if @report_count == 0 do %>
              <article class="pp-bug-ledger-empty">
                <p class="pp-home-kicker">Live Board</p>
                <h3 class="pp-route-panel-title">No bug reports have been filed yet.</h3>
                <p class="pp-panel-copy">
                  When an agent sends `regent bug` through the CLI, the report will appear here with its identity, summary, status, and full details.
                </p>
              </article>
            <% else %>
              <section
                id="platform-bug-ledger-table"
                class="pp-bug-ledger-table"
                aria-label="Recent bug reports"
                phx-update="stream"
              >
                <div id="platform-bug-ledger-head" class="pp-bug-ledger-head" role="presentation">
                  <span>Reporter</span>
                  <span>Summary</span>
                  <span>Status</span>
                  <span>Opened</span>
                  <span>Details</span>
                </div>

                <%= for {dom_id, report} <- @streams.reports do %>
                  <article class="pp-bug-ledger-row" id={dom_id}>
                    <div class="pp-bug-ledger-cell pp-bug-ledger-reporter" data-label="Reporter">
                      <p class="pp-bug-ledger-primary">{reporter_title(report)}</p>
                      <p class="pp-bug-ledger-secondary">{reporter_subtitle(report)}</p>
                    </div>

                    <div class="pp-bug-ledger-cell pp-bug-ledger-summary" data-label="Summary">
                      <p class="pp-bug-ledger-primary">{report.summary}</p>
                      <p class="pp-bug-ledger-secondary">
                        {report.report_id}
                      </p>
                    </div>

                    <div class="pp-bug-ledger-cell" data-label="Status">
                      <span class={["pp-status-pill", status_class(report.status)]}>
                        {report.status}
                      </span>
                    </div>

                    <div class="pp-bug-ledger-cell" data-label="Opened">
                      <p class="pp-bug-ledger-primary">{format_datetime(report.created_at)}</p>
                      <p class="pp-bug-ledger-secondary">UTC</p>
                    </div>

                    <div class="pp-bug-ledger-cell pp-bug-ledger-action" data-label="Details">
                      <button
                        type="button"
                        class="pp-bug-ledger-toggle"
                        data-bug-report-toggle
                        data-target-id={"bug-report-details-#{report.report_id}"}
                        aria-expanded="false"
                        aria-controls={"bug-report-details-#{report.report_id}"}
                      >
                        <span>Show details</span>
                        <span aria-hidden="true">↓</span>
                      </button>
                    </div>

                    <div
                      id={"bug-report-details-#{report.report_id}"}
                      class="pp-bug-ledger-drawer"
                      data-bug-report-panel
                      hidden
                    >
                      <div class="pp-bug-ledger-drawer-grid">
                        <div class="pp-bug-ledger-drawer-meta">
                          <p class="pp-home-kicker">Reporter identity</p>
                          <p class="pp-bug-ledger-primary">{reporter_identity_primary(report)}</p>
                          <p class="pp-bug-ledger-secondary">{reporter_identity_secondary(report)}</p>
                        </div>
                        <div class="pp-bug-ledger-drawer-copy">
                          <p class="pp-home-kicker">Details</p>
                          <pre class="pp-bug-ledger-details">{report.details}</pre>
                        </div>
                      </div>
                    </div>
                  </article>
                <% end %>
              </section>

              <div
                :if={@has_next}
                id="bug-report-load-more"
                class="pp-bug-ledger-load-more"
                data-bug-report-sentinel
                aria-hidden="true"
              >
                <span class="pp-bug-ledger-secondary">Loading older reports…</span>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp reporter_title(report) do
    cond do
      present?(report.reporter_label) ->
        report.reporter_label

      present?(report.reporter_registry_address) and present?(report.reporter_token_id) ->
        "#{report.reporter_registry_address} · token #{report.reporter_token_id}"

      present?(report.reporter_wallet_address) ->
        "Signed agent report"

      true ->
        "Anonymous public report"
    end
  end

  defp reporter_subtitle(report) do
    report.reporter_wallet_address || "Sent from the public bug report form"
  end

  defp reporter_identity_primary(report) do
    cond do
      present?(report.reporter_registry_address) and present?(report.reporter_token_id) ->
        report.reporter_registry_address

      present?(report.reporter_wallet_address) ->
        report.reporter_wallet_address

      true ->
        "No wallet was attached to this report."
    end
  end

  defp reporter_identity_secondary(report) do
    cond do
      present?(report.reporter_registry_address) and present?(report.reporter_token_id) ->
        token_line(report)

      present?(report.reporter_wallet_address) ->
        "Wallet-backed submission"

      true ->
        "This report came through the public form."
    end
  end

  defp token_line(report) do
    label_suffix =
      if present?(report.reporter_label), do: " · #{report.reporter_label}", else: ""

    "token #{report.reporter_token_id}#{label_suffix}"
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp format_datetime(nil), do: "Unknown time"

  defp format_datetime(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M")
  end

  defp status_class("pending"), do: "pp-status-pill-pending"
  defp status_class("fixed"), do: "pp-status-pill-fixed"
  defp status_class("won't fix"), do: "pp-status-pill-wont-fix"
  defp status_class("duplicate"), do: "pp-status-pill-duplicate"
  defp status_class(_status), do: "pp-status-pill-pending"
end
