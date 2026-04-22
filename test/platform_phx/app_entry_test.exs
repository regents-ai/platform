defmodule PlatformPhx.AppEntryTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AppEntry
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)
    previous_api_key = System.get_env("OPENSEA_API_KEY")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    System.put_env("OPENSEA_API_KEY", "test-key")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      OpenSea.clear_cache()
    end)

    :ok
  end

  test "sends anonymous visitors to access" do
    assert AppEntry.next_step_for_user(nil) == :access
  end

  test "raises when the formation payload cannot be loaded" do
    human = insert_human!("not_connected")

    assert_raise BadMapError, fn ->
      AppEntry.next_step_for_user(human)
    end
  end

  defp insert_human!(stripe_status) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: @address,
      wallet_addresses: [@address],
      display_name: "operator@regents.sh",
      stripe_llm_billing_status: stripe_status
    })
    |> Repo.insert!()
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)
end
