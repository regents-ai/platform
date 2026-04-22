defmodule PlatformPhxWeb.AppEntryLive do
  use PlatformPhxWeb, :live_view

  alias PlatformPhx.AppEntry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "App")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     push_navigate(socket, to: AppEntry.next_path_for_user(socket.assigns.current_human))}
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
      header_eyebrow="Regents"
      header_title="Opening the app"
      theme_class="rg-regent-theme-platform"
    >
      <div class="flex min-h-[20rem] items-center justify-center">
        <p class="text-sm text-[color:var(--muted-foreground)]">Checking the next step…</p>
      </div>
    </Layouts.app>
    """
  end
end
