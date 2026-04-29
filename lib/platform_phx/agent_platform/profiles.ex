defmodule PlatformPhx.AgentPlatform.Profiles do
  @moduledoc false

  alias PlatformPhx.Accounts
  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform

  def save_human_avatar(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before saving an avatar"}}

  def save_human_avatar(%HumanUser{} = human, attrs) when is_map(attrs) do
    with {:ok, holdings} <- avatar_holdings(human, attrs),
         {:ok, avatar} <- AvatarSelection.normalize(attrs, holdings),
         {:ok, updated_human} <- Accounts.update_human(human, %{avatar: avatar}) do
      human
      |> AgentPlatform.list_owned_agents()
      |> Enum.each(&AgentPlatform.clear_public_agent_cache/1)

      {:ok, updated_human}
    else
      {:error, :unconfigured} ->
        {:error, {:unavailable, "Avatar saving is unavailable right now"}}

      {:error, {:bad_request, _message}} = error ->
        error

      {:error, {:external, _service, _message}} ->
        {:error, {:unavailable, "Could not confirm wallet holdings right now"}}

      {:error, message} when is_binary(message) ->
        {:error, {:bad_request, message}}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:bad_request, AgentPlatform.format_changeset(changeset)}}

      {:error, _reason} ->
        {:error, {:bad_request, "Could not save that avatar"}}
    end
  end

  defp avatar_holdings(%HumanUser{} = human, attrs) do
    if AvatarSelection.collection_token_selection?(attrs) do
      AgentPlatform.holdings_for_human(human)
    else
      {:ok, AgentPlatform.empty_holdings()}
    end
  end
end
