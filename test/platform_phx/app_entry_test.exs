defmodule PlatformPhx.AppEntryTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Billing
  alias PlatformPhx.AppEntry
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)

    previous_agent_formation_enabled =
      Application.get_env(:platform_phx, :agent_formation_enabled)

    previous_api_key = System.get_env("OPENSEA_API_KEY")
    previous_agent_formation_enabled_env = System.get_env("AGENT_FORMATION_ENABLED")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    Application.put_env(:platform_phx, :agent_formation_enabled, true)
    System.put_env("OPENSEA_API_KEY", "test-key")
    System.delete_env("AGENT_FORMATION_ENABLED")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_app_env(:platform_phx, :agent_formation_enabled, previous_agent_formation_enabled)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      restore_system_env("AGENT_FORMATION_ENABLED", previous_agent_formation_enabled_env)
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

  test "sends ready users to staking when company opening is paused" do
    Application.put_env(:platform_phx, :agent_formation_enabled, false)

    human = insert_human!("active")
    insert_claimed_name!(human, "staking")
    {:ok, _billing_account} = Billing.ensure_account(human)

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    assert AppEntry.next_step_for_user(human) == :token_info
    assert AppEntry.next_path_for_user(human) == "/token-info"
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

  defp insert_claimed_name!(human, label) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Mint{}
    |> Mint.changeset(%{
      parent_node: "0xparent",
      parent_name: "agent.base.eth",
      label: label,
      fqdn: "#{label}.agent.base.eth",
      node: "0x#{label}",
      ens_fqdn: "#{label}.regent.eth",
      ens_node: "0xens#{label}",
      owner_address: human.wallet_address,
      tx_hash: "0xtx#{label}",
      ens_tx_hash: "0xenstx#{label}",
      ens_assigned_at: now,
      is_free: true,
      is_in_use: false
    })
    |> Repo.insert!()
  end

  defp request_url(address, collection) do
    "https://api.opensea.io/api/v2/chain/base/account/#{address}/nfts?collection=#{collection}&limit=100"
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(name, nil), do: System.delete_env(name)
  defp restore_system_env(name, value), do: System.put_env(name, value)
end
