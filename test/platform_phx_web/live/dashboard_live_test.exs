defmodule PlatformPhxWeb.DashboardLiveTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.Workers.RunFormationWorker
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)
    previous_sprite_runner = Application.get_env(:platform_phx, :agent_platform_sprite_runner)
    previous_api_key = System.get_env("OPENSEA_API_KEY")
    previous_stripe_secret_key = System.get_env("STRIPE_SECRET_KEY")
    previous_pricing_plan_id = System.get_env("STRIPE_BILLING_PRICING_PLAN_ID")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)

    Application.put_env(
      :platform_phx,
      :agent_platform_sprite_runner,
      PlatformPhx.SpriteRunnerFake
    )

    System.put_env("OPENSEA_API_KEY", "test-key")
    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")
    System.put_env("STRIPE_BILLING_PRICING_PLAN_ID", "pp_test_agent_formation")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)
      restore_app_env(:platform_phx, :agent_platform_sprite_runner, previous_sprite_runner)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      restore_system_env("STRIPE_SECRET_KEY", previous_stripe_secret_key)
      restore_system_env("STRIPE_BILLING_PRICING_PLAN_ID", previous_pricing_plan_id)
      OpenSea.clear_cache()
    end)

    :ok
  end

  test "agent formation route shows signed-in names and Regents Club cards", %{conn: conn} do
    human = insert_human!("not_connected")
    insert_claimed_name!(human, "tempo")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") =>
        {:ok,
         %{
           "nfts" => [%{"collection" => "regents-club", "identifier" => "11"}],
           "next" => nil
         }}
    })

    {:ok, _view, html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/agent-formation")

    assert html =~ "tempo.regent.eth"
    assert html =~ "/cards/regents-club/11"
    assert html =~ "Passes found"
    assert html =~ "Continue"
    assert html =~ "data-wallet-signed-in=\"true\""
    assert html =~ "Wallet Connected"
    assert html =~ "0xf39f...2266"
    refute html =~ "Keep formation updates in one shared room"
    refute html =~ "agent-formation-room"
  end

  test "agent formation continue opens the setup state with the updated billing copy", %{
    conn: conn
  } do
    human = insert_human!("not_connected")
    insert_claimed_name!(human, "tempo")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/agent-formation")

    view
    |> element("button", "Continue")
    |> render_click()

    assert_patch(view, "/agent-formation?claimedLabel=tempo&stage=setup")

    html = render(view)
    assert html =~ "Complete Agent Formation"

    assert html =~
             "Pick one unused name, make sure billing is active, and start the company launch for your wallet."

    assert html =~ "tempo.regent.eth"
  end

  test "services route links collection chips to their item pages", %{conn: conn} do
    human = insert_human!("not_connected")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") =>
        {:ok,
         %{
           "nfts" => [%{"collection" => "regent-animata-ii", "identifier" => "588"}],
           "next" => nil
         }},
      request_url(@address, "regents-club") =>
        {:ok,
         %{
           "nfts" => [%{"collection" => "regents-club", "identifier" => "11"}],
           "next" => nil
         }}
    })

    {:ok, _view, html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/services")

    assert html =~ "https://opensea.io/item/base/0x78402119ec6349a0d41f12b54938de7bf783c923/7"

    assert html =~
             "https://opensea.io/item/base/0x903c4c1e8b8532fbd3575482d942d493eb9266e2/588"

    assert html =~ "/cards/regents-club/11"
  end

  test "billing setup keeps the selected name and launch redirects to the company site", %{
    conn: conn
  } do
    launch_label = "tempo-launch"
    human = insert_human!("active")
    insert_billing_account!(human, 900)
    insert_claimed_name!(human, launch_label)

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/agent-formation?stage=setup&claimedLabel=#{launch_label}")

    view
    |> element("button", "Launch my company")
    |> render_click()

    agent = AgentPlatform.get_owned_agent(human, launch_label)
    assert agent
    assert :ok == perform_job(RunFormationWorker, %{"agent_id" => agent.id})

    send(view.pid, :refresh_formation_payload)

    assert_redirect(view, "https://#{launch_label}.regents.sh")
  end

  test "billing setup checkout returns to the launch page with the selected name", %{conn: conn} do
    human = insert_human!("not_connected")
    insert_claimed_name!(human, "tempo")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/agent-formation?stage=setup&claimedLabel=tempo")

    view
    |> element("button", "Set up billing")
    |> render_click()

    assert_redirect(
      view,
      "https://billing.stripe.test/checkout/agent-formation?success_url=http%3A%2F%2Flocalhost%3A4000%2Fagent-formation%3Fbilling%3Dsuccess%26claimedLabel%3Dtempo%26stage%3Dsetup&cancel_url=http%3A%2F%2Flocalhost%3A4000%2Fagent-formation%3Fbilling%3Dcancel%26claimedLabel%3Dtempo%26stage%3Dsetup"
    )
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

  defp insert_billing_account!(human, balance_cents) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      stripe_pricing_plan_subscription_id: "sub_#{System.unique_integer([:positive])}",
      billing_status: "active",
      runtime_credit_balance_usd_cents: balance_cents
    })
    |> Repo.insert!()
  end

  defp request_url(address, collection) do
    "https://api.opensea.io/api/v2/chain/base/account/#{address}/nfts?collection=#{collection}&limit=100"
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
end
