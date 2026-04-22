defmodule PlatformPhx.DashboardTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Basenames
  alias PlatformPhx.Dashboard

  setup do
    previous_basename_parent = System.get_env("AGENT_BASENAME_PARENT_NAME")
    previous_ens_parent = System.get_env("AGENT_PROTOCOL_ENS_PARENT_NAME")

    on_exit(fn ->
      restore_system_env("AGENT_BASENAME_PARENT_NAME", previous_basename_parent)
      restore_system_env("AGENT_PROTOCOL_ENS_PARENT_NAME", previous_ens_parent)
    end)

    :ok
  end

  test "uses the current runtime names for a claim state" do
    state = Dashboard.name_claim_state("fresh", "wrong.eth", "wrong.regent.eth")

    assert state.valid? == true
    assert state.available? in [true, false]
    assert state.fqdn == "fresh.#{Basenames.parent_name()}"
    assert state.ens_fqdn == "fresh.#{Basenames.ens_parent_name()}"
    assert state.label_error == nil
  end

  test "keeps unavailable claims empty when runtime names cannot be loaded" do
    previous_adapter = Application.get_env(:platform_phx, :ethereum_adapter)
    previous_path = System.get_env("PATH")

    Application.put_env(:platform_phx, :ethereum_adapter, PlatformPhx.Ethereum.CastAdapter)
    System.put_env("PATH", "")

    on_exit(fn ->
      restore_app_env(:platform_phx, :ethereum_adapter, previous_adapter)
      restore_system_env("PATH", previous_path)
    end)

    System.put_env("AGENT_BASENAME_PARENT_NAME", "bad parent")
    System.put_env("AGENT_PROTOCOL_ENS_PARENT_NAME", "bad parent")

    state = Dashboard.name_claim_state("fresh", "wrong.eth", "wrong.regent.eth")

    assert state.valid? == false
    assert state.available? == nil
    assert state.fqdn == nil
    assert state.ens_fqdn == nil
    assert state.label_error == "Name settings are unavailable right now."
  end

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
