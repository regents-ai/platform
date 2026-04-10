defmodule PlatformPhxWeb.Api.AgentFormationControllerTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Workers.RunFormationWorker
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup do
    previous_client = Application.get_env(:platform_phx, :opensea_http_client)
    previous_responses = Application.get_env(:platform_phx, :opensea_fake_responses)
    previous_stripe_client = Application.get_env(:platform_phx, :stripe_llm_client)
    previous_sprite_runner = Application.get_env(:platform_phx, :agent_platform_sprite_runner)
    previous_api_key = System.get_env("OPENSEA_API_KEY")
    previous_stripe_secret_key = System.get_env("STRIPE_SECRET_KEY")
    previous_webhook_secret = System.get_env("STRIPE_WEBHOOK_SECRET")
    previous_pricing_plan_id = System.get_env("STRIPE_LLM_PRICING_PLAN_ID")
    previous_success_url = System.get_env("STRIPE_LLM_SUCCESS_URL")
    previous_cancel_url = System.get_env("STRIPE_LLM_CANCEL_URL")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    Application.put_env(:platform_phx, :stripe_llm_client, PlatformPhx.StripeLlmFakeClient)

    Application.put_env(
      :platform_phx,
      :agent_platform_sprite_runner,
      PlatformPhx.SpriteRunnerFake
    )

    System.put_env("OPENSEA_API_KEY", "test-key")
    System.put_env("STRIPE_SECRET_KEY", "sk_test_agent_formation")
    System.put_env("STRIPE_WEBHOOK_SECRET", "whsec_test")
    System.put_env("STRIPE_LLM_PRICING_PLAN_ID", "pp_test_agent_formation")
    System.put_env("STRIPE_LLM_SUCCESS_URL", "https://regents.sh/services?billing=success")
    System.put_env("STRIPE_LLM_CANCEL_URL", "https://regents.sh/services?billing=cancel")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_app_env(:platform_phx, :stripe_llm_client, previous_stripe_client)
      restore_app_env(:platform_phx, :agent_platform_sprite_runner, previous_sprite_runner)
      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      restore_system_env("STRIPE_SECRET_KEY", previous_stripe_secret_key)
      restore_system_env("STRIPE_WEBHOOK_SECRET", previous_webhook_secret)
      restore_system_env("STRIPE_LLM_PRICING_PLAN_ID", previous_pricing_plan_id)
      restore_system_env("STRIPE_LLM_SUCCESS_URL", previous_success_url)
      restore_system_env("STRIPE_LLM_CANCEL_URL", previous_cancel_url)
      OpenSea.clear_cache()
    end)

    :ok
  end

  test "formation returns unauthenticated state without a session", %{conn: conn} do
    response =
      conn
      |> get("/api/agent-platform/formation")
      |> json_response(200)

    assert response["authenticated"] == false
    assert response["eligible"] == false
    assert response["available_claims"] == []
    assert response["llm_billing"]["connected"] == false
  end

  test "formation shows eligible holdings and claimed names for a signed-in human", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "tempo")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/formation")
      |> json_response(200)

    assert response["authenticated"] == true
    assert response["eligible"] == true
    assert get_in(response, ["collections", "animata1"]) == [7]
    assert Enum.map(response["available_claims"], & &1["label"]) == ["tempo"]
  end

  test "billing checkout, webhook sync, and formation queue a company", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "startline")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    conn = init_test_session(conn, %{current_human_id: human.id})

    billing_response =
      conn
      |> post("/api/agent-platform/formation/llm-billing/checkout")
      |> json_response(200)

    assert billing_response["checkout_url"] =~ "billing.stripe.test"

    raw_body = stripe_event_body(human.id)

    webhook_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
      |> post("/api/agent-platform/stripe/webhooks", raw_body)

    assert json_response(webhook_conn, 200)["ok"] == true

    [job] = all_enqueued(worker: PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker)
    assert :ok == perform_job(worker_module(job.worker), job.args)

    response =
      conn
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "startline"})
      |> json_response(202)

    assert response["agent"]["slug"] == "startline"
    assert response["agent"]["template_key"] == "start"
    assert response["agent"]["status"] == "forming"
    assert response["agent"]["subdomain"]["hostname"] == "startline.regents.sh"
    assert response["agent"]["subdomain"]["active"] == false
    assert response["agent"]["stripe_llm_billing_status"] == "active"
    assert response["agent"]["runtime_status"] == "queued"
    assert response["formation"]["status"] == "queued"
    assert response["formation"]["current_step"] == "reserve_claim"

    mint = Repo.get_by!(Mint, label: "startline")
    assert mint.is_in_use == true

    [formation_job] = all_enqueued(worker: RunFormationWorker)
    assert :ok == perform_job(worker_module(formation_job.worker), formation_job.args)

    runtime_response =
      conn
      |> get("/api/agent-platform/agents/startline/runtime")
      |> json_response(200)

    assert runtime_response["agent"]["status"] == "published"
    assert runtime_response["agent"]["subdomain"]["active"] == true
    assert runtime_response["runtime"]["sprite"]["owner"] == "regents"
    assert runtime_response["runtime"]["hermes"]["adapter_type"] == "hermes_local"
    assert runtime_response["runtime"]["hermes"]["model"] == "glm-5.1"
    assert runtime_response["formation"]["status"] == "succeeded"
  end

  defp insert_human! do
    %HumanUser{}
    |> HumanUser.changeset(%{
      privy_user_id: "privy-123",
      wallet_address: @address,
      wallet_addresses: [@address],
      display_name: "operator@regents.sh"
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

  defp stripe_event_body(human_user_id) do
    Jason.encode!(%{
      id: "evt_test_checkout",
      type: "checkout.session.completed",
      data: %{
        object: %{
          customer: "cus_test_agent_formation",
          subscription: "sub_test_agent_formation",
          status: "active",
          metadata: %{"human_user_id" => Integer.to_string(human_user_id)}
        }
      }
    })
  end

  defp stripe_signature(raw_body, secret) do
    timestamp = Integer.to_string(System.system_time(:second))

    signed =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signed}"
  end

  defp worker_module(worker) when is_atom(worker), do: worker
  defp worker_module(worker) when is_binary(worker), do: Module.concat([worker])

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
end
