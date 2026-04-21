defmodule PlatformPhxWeb.DashboardLiveTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  import Phoenix.LiveViewTest

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_billing_client)
    previous_sprite_runner = Application.get_env(:platform_phx, :agent_platform_sprite_runner)
    previous_sprite_runtime_client = Application.get_env(:platform_phx, :sprite_runtime_client)
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

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientFake
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
      restore_app_env(:platform_phx, :sprite_runtime_client, previous_sprite_runtime_client)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      restore_system_env("STRIPE_SECRET_KEY", previous_stripe_secret_key)
      restore_system_env("STRIPE_BILLING_PRICING_PLAN_ID", previous_pricing_plan_id)
      OpenSea.clear_cache()
    end)

    :ok
  end

  test "app entry sends an anonymous visitor to access", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/app/access"}}} = live(conn, "/app")
  end

  test "app entry sends an eligible signed-in visitor without a claimed name to identity", %{
    conn: conn
  } do
    human = insert_human!("not_connected")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    assert {:error, {:live_redirect, %{to: "/app/identity"}}} =
             conn
             |> init_test_session(%{current_human_id: human.id})
             |> live("/app")
  end

  test "app entry sends a signed-in visitor with a claimed name and no billing to billing", %{
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

    assert {:error, {:live_redirect, %{to: "/app/billing"}}} =
             conn
             |> init_test_session(%{current_human_id: human.id})
             |> live("/app")
  end

  test "billing setup checkout returns to the new app routes with the selected name", %{
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
      |> live("/app/billing?claimedLabel=tempo")

    view
    |> element("button", "Set up billing")
    |> render_click()

    assert_redirect(
      view,
      "https://billing.stripe.test/checkout/agent-formation?success_url=http%3A%2F%2Flocalhost%3A4000%2Fapp%2Fformation%3Fbilling%3Dsuccess%26claimedLabel%3Dtempo&cancel_url=http%3A%2F%2Flocalhost%3A4000%2Fapp%2Fbilling%3Fbilling%3Dcancel%26claimedLabel%3Dtempo"
    )
  end

  test "dashboard route renders a safe no-company state for anonymous visitors", %{conn: conn} do
    {:ok, _dashboard, html} = live(conn, "/app/dashboard")

    assert html =~ "Open a company to make this your home."
    assert html =~ "Open Agent Formation"
    assert html =~ "Techtree"
    assert html =~ "Autolaunch"
    refute html =~ "Pause company"
  end

  test "dashboard route renders a safe no-company state for signed-in visitors without a company",
       %{conn: conn} do
    human = insert_human!("not_connected")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    {:ok, _dashboard, html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/app/dashboard")

    assert html =~ "Open a company to make this your home."
    assert html =~ "Open Agent Formation"
    assert html =~ "Techtree"
    assert html =~ "Autolaunch"
    refute html =~ "Pause company"
  end

  test "formation opens provisioning and dashboard shows company controls", %{conn: conn} do
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
      |> live("/app/formation?claimedLabel=#{launch_label}")

    view
    |> element("button", "Open company")
    |> render_click()

    agent = AgentPlatform.get_owned_agent(human, launch_label)
    assert agent

    assert_redirect(view, "/app/provisioning/#{agent.formation_run.id}")

    {:ok, _dashboard, dashboard_html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/app/dashboard")

    assert dashboard_html =~ "Control the hosted company from here."
    assert dashboard_html =~ "Pause company"
    assert dashboard_html =~ "Techtree"
    assert dashboard_html =~ "Autolaunch"
    assert dashboard_html =~ launch_label
  end

  test "dashboard shows the avatar creator with the saved avatar and owned choices", %{conn: conn} do
    launch_label = "avatar-launch"

    human =
      insert_human!("active", %{
        avatar: %{
          "kind" => "collection_token",
          "collection" => "animataPass",
          "token_id" => 11,
          "preview_type" => "token_card",
          "gold_border" => true
        }
      })

    insert_billing_account!(human, 900)
    insert_claimed_name!(human, launch_label)

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") =>
        {:ok,
         %{"nfts" => [%{"collection" => "regent-animata-ii", "identifier" => "9"}], "next" => nil}},
      request_url(@address, "regents-club") =>
        {:ok,
         %{"nfts" => [%{"collection" => "regents-club", "identifier" => "11"}], "next" => nil}}
    })

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/app/formation?claimedLabel=#{launch_label}")

    view
    |> element("button", "Open company")
    |> render_click()

    {:ok, _dashboard, dashboard_html} =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> live("/app/dashboard")

    assert dashboard_html =~ "Agent Avatar Creator"
    assert dashboard_html =~ "Current saved avatar"
    assert dashboard_html =~ "Gold border rule"
    assert dashboard_html =~ "Collection I"
    assert dashboard_html =~ "Collection II"
    assert dashboard_html =~ "Open shader studio"
    assert dashboard_html =~ "dashboard-avatar-animata-pass-11"
  end

  defp insert_human!(stripe_status, attrs \\ %{}) do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-#{System.unique_integer([:positive])}",
      wallet_address: @address,
      wallet_addresses: [@address],
      display_name: "operator@regents.sh",
      stripe_llm_billing_status: stripe_status,
      avatar: Map.get(attrs, :avatar)
    })
    |> Repo.insert!()
  end

  defp insert_claimed_name!(human, label, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
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
      is_free: Map.get(attrs, :is_free, true),
      is_in_use: Map.get(attrs, :is_in_use, false)
    })
    |> Repo.insert!()
  end

  defp insert_billing_account!(human, balance_cents) do
    unique_suffix = "#{human.id}-#{System.unique_integer([:positive])}"

    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      stripe_customer_id: "cus_#{unique_suffix}",
      stripe_pricing_plan_subscription_id: "sub_#{unique_suffix}",
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
