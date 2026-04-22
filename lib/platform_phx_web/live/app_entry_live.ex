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
      <div class="flex min-h-[20rem] items-center justify-center px-4">
        <div class="w-full max-w-[30rem] rounded-[1.8rem] border border-[color:color-mix(in_oklch,var(--border)_88%,transparent)] bg-[color:color-mix(in_oklch,var(--background)_96%,var(--card)_4%)] px-6 py-6 text-center shadow-[0_22px_52px_-36px_color-mix(in_oklch,var(--brand-ink)_30%,transparent)]">
          <div class="mx-auto flex size-12 items-center justify-center rounded-[1rem] bg-[color:color-mix(in_oklch,var(--brand-ink)_10%,var(--background)_90%)] text-[color:var(--brand-ink)]">
            <.icon name="hero-arrow-right" class="size-6" />
          </div>
          <h2 class="mt-4 font-display text-[2rem] leading-none tracking-[-0.05em] text-[color:var(--foreground)]">
            Opening Regents
          </h2>
          <p class="mt-3 text-sm leading-6 text-[color:var(--muted-foreground)]">
            Finding the next place for you now.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
