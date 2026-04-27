defmodule PlatformPhx.AgentPlatform.FormationReadinessTest do
  use PlatformPhx.DataCase, async: false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhx.AgentPlatform.Formation.Readiness
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @required_step_keys [
    "identity",
    "wallet",
    "access",
    "name",
    "billing",
    "template",
    "company",
    "launch_queue"
  ]

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)
    previous_api_key = System.get_env("OPENSEA_API_KEY")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    System.put_env("OPENSEA_API_KEY", "test-key")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:opensea_http_client, previous_client)
      restore_app_env(:opensea_fake_responses, previous_responses)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      OpenSea.clear_cache()
    end)

    :ok
  end

  test "readiness payload keeps every required step for signed-out people" do
    readiness =
      Readiness.payload(%{
        authenticated: false,
        wallet_connected?: false,
        eligible: false,
        available_claims: [],
        billing_account: %{connected: false, status: "not_connected"},
        template_ready?: true,
        owned_companies: [],
        active_formations: []
      })

    assert readiness.ready == false
    assert readiness.blocked_step.key == "identity"
    assert Enum.map(readiness.steps, & &1.key) == @required_step_keys

    assert Enum.map(readiness.steps, & &1.status) == [
             "needs_action",
             "waiting",
             "waiting",
             "waiting",
             "waiting",
             "waiting",
             "waiting",
             "waiting"
           ]

    assert Enum.map(readiness.steps, &(Map.keys(&1) |> Enum.sort())) ==
             List.duplicate(
               Enum.sort([:action_label, :action_path, :key, :label, :message, :status]),
               length(@required_step_keys)
             )
  end

  test "readiness payload keeps every required step when company opening is ready" do
    readiness =
      Readiness.payload(%{
        authenticated: true,
        wallet_connected?: true,
        eligible: true,
        available_claims: [%{label: "fresh"}],
        billing_account: %{connected: true, status: "active"},
        template_ready?: true,
        owned_companies: [],
        active_formations: []
      })

    assert readiness.ready == true
    assert readiness.blocked_step == nil
    assert Enum.map(readiness.steps, & &1.key) == @required_step_keys

    assert Enum.map(readiness.steps, & &1.status) == [
             "complete",
             "complete",
             "complete",
             "complete",
             "complete",
             "complete",
             "ready",
             "ready"
           ]

    assert List.last(readiness.steps).message == "Launch can start when you open the company."
  end

  test "formation payload offers unused claimed names and hides used claimed names" do
    human = insert_human!()
    insert_claimed_name!(human, "fresh")
    insert_claimed_name!(human, "marked", %{is_in_use: true})
    insert_claimed_name!(human, "forming", %{formation_agent_slug: "forming"})
    insert_claimed_name!(human, "attached", %{attached_agent_slug: "attached"})

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    assert {:ok, payload} = Formation.formation_payload(human)

    assert Enum.map(payload.available_claims, & &1.label) == ["fresh"]

    assert Map.new(payload.claimed_names, &{&1.label, &1.in_use}) == %{
             "attached" => true,
             "forming" => true,
             "fresh" => false,
             "marked" => true
           }
  end

  defp insert_human! do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: @address,
      wallet_addresses: [@address],
      display_name: "operator@regents.sh"
    })
    |> Repo.insert!()
  end

  defp insert_claimed_name!(human, label, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
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
    }

    %Mint{}
    |> Mint.changeset(Map.merge(defaults, Enum.into(attrs, %{})))
    |> Repo.insert!()
  end

  defp request_url(address, collection) do
    "https://api.opensea.io/api/v2/chain/base/account/#{address}/nfts?collection=#{collection}&limit=100"
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:platform_phx, key)
  defp restore_app_env(key, value), do: Application.put_env(:platform_phx, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
end
