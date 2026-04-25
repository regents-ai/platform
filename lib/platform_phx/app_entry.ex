defmodule PlatformPhx.AppEntry do
  @moduledoc false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Dashboard
  alias PlatformPhx.RuntimeConfig

  @type next_step ::
          :access
          | :identity
          | :billing
          | :formation
          | :token_info
          | :dashboard
          | {:provisioning, integer()}

  def next_step_for_user(%HumanUser{} = human) do
    {:ok, %{formation: formation}} = Dashboard.agent_formation_payload(human)
    next_step_for_payload(formation)
  end

  def next_step_for_user(_human), do: :access

  def next_path_for_user(human) do
    case next_step_for_user(human) do
      :access -> "/app/access"
      :identity -> "/app/identity"
      :billing -> "/app/billing"
      :formation -> "/app/formation"
      :token_info -> "/token-info"
      :dashboard -> "/app/dashboard"
      {:provisioning, formation_id} -> "/app/provisioning/#{formation_id}"
    end
  end

  defp next_step_for_payload(formation) do
    cond do
      formation.authenticated != true ->
        :access

      formation.eligible != true ->
        :access

      active = active_formation(formation) ->
        {:provisioning, active.id}

      formation.owned_companies != [] ->
        :dashboard

      formation.available_claims == [] ->
        :identity

      formation.billing_account.connected != true ->
        :billing

      RuntimeConfig.agent_formation_enabled?() ->
        :formation

      true ->
        :token_info
    end
  end

  defp active_formation(%{active_formations: active_formations})
       when is_list(active_formations) do
    Enum.find(active_formations, &(&1.status in ["queued", "running"]))
  end

  defp active_formation(_formation), do: nil
end
