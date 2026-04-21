defmodule PlatformPhxWeb.LivePageMetadata do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhxWeb.SiteUrl

  def on_mount(:default, _params, session, socket) do
    current_url = session["current_url"]

    {:cont,
     socket
     |> maybe_assign_canonical(current_url)
     |> Phoenix.LiveView.attach_hook(:live_page_metadata, :handle_params, fn _params,
                                                                             uri,
                                                                             socket ->
       {:cont, assign(socket, :canonical_url, SiteUrl.canonicalize_uri(uri))}
     end)}
  end

  defp maybe_assign_canonical(socket, current_url) when is_binary(current_url) do
    assign(socket, :canonical_url, SiteUrl.canonicalize_uri(current_url))
  end

  defp maybe_assign_canonical(socket, _current_url), do: socket
end
