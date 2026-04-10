defmodule PlatformPhxWeb.LiveCurrentHuman do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  alias PlatformPhx.Accounts

  def on_mount(:default, _params, session, socket) do
    current_human = Accounts.get_human(session["current_human_id"])
    {:cont, assign(socket, :current_human, current_human)}
  end
end
