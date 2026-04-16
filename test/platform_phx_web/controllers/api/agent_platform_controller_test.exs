defmodule PlatformPhxWeb.Api.AgentFormationControllerTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo
  import Ecto.Query

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.FormationEvent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.WelcomeCreditGrant
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
    previous_sprite_runtime_client = Application.get_env(:platform_phx, :sprite_runtime_client)

    previous_credit_grant_result =
      Application.get_env(:platform_phx, :stripe_fake_credit_grant_result)

    previous_runtime_transition_states =
      Application.get_env(:platform_phx, :sprite_runtime_transition_states)

    previous_runtime_topups = Application.get_env(:platform_phx, :runtime_topups, [])
    previous_formation = Application.get_env(:platform_phx, :formation, [])
    previous_runtime_test_pid = Application.get_env(:platform_phx, :sprite_runtime_test_pid)

    previous_runtime_start_result =
      Application.get_env(:platform_phx, :sprite_runtime_start_result)

    previous_runtime_stop_result = Application.get_env(:platform_phx, :sprite_runtime_stop_result)

    previous_runtime_service_state =
      Application.get_env(:platform_phx, :sprite_runtime_service_state)

    previous_api_key = System.get_env("OPENSEA_API_KEY")
    previous_stripe_secret_key = System.get_env("STRIPE_SECRET_KEY")
    previous_webhook_secret = System.get_env("STRIPE_WEBHOOK_SECRET")
    previous_pricing_plan_id = System.get_env("STRIPE_BILLING_PRICING_PLAN_ID")
    previous_topup_success_url = System.get_env("STRIPE_BILLING_TOPUP_SUCCESS_URL")
    previous_topup_cancel_url = System.get_env("STRIPE_BILLING_TOPUP_CANCEL_URL")
    previous_runtime_meter_name = System.get_env("STRIPE_RUNTIME_METER_EVENT_NAME")
    previous_welcome_credit_enabled = System.get_env("WELCOME_CREDIT_ENABLED")
    previous_welcome_credit_limit = System.get_env("WELCOME_CREDIT_LIMIT")
    previous_welcome_credit_amount = System.get_env("WELCOME_CREDIT_AMOUNT_USD_CENTS")
    previous_welcome_credit_expiry = System.get_env("WELCOME_CREDIT_EXPIRY_DAYS")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)

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
    System.put_env("STRIPE_WEBHOOK_SECRET", "whsec_test")
    System.put_env("STRIPE_BILLING_PRICING_PLAN_ID", "pp_test_agent_formation")

    System.put_env(
      "STRIPE_BILLING_TOPUP_SUCCESS_URL",
      "https://regents.sh/services?topup=success"
    )

    System.put_env("STRIPE_BILLING_TOPUP_CANCEL_URL", "https://regents.sh/services?topup=cancel")
    System.put_env("STRIPE_RUNTIME_METER_EVENT_NAME", "sprite_runtime_seconds")
    System.put_env("WELCOME_CREDIT_ENABLED", "true")
    System.put_env("WELCOME_CREDIT_LIMIT", "100")
    System.put_env("WELCOME_CREDIT_AMOUNT_USD_CENTS", "500")
    System.put_env("WELCOME_CREDIT_EXPIRY_DAYS", "60")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)
      restore_app_env(:platform_phx, :agent_platform_sprite_runner, previous_sprite_runner)
      restore_app_env(:platform_phx, :sprite_runtime_client, previous_sprite_runtime_client)

      restore_app_env(
        :platform_phx,
        :stripe_fake_credit_grant_result,
        previous_credit_grant_result
      )

      restore_app_env(
        :platform_phx,
        :sprite_runtime_transition_states,
        previous_runtime_transition_states
      )

      Application.put_env(:platform_phx, :runtime_topups, previous_runtime_topups)
      Application.put_env(:platform_phx, :formation, previous_formation)
      restore_app_env(:platform_phx, :sprite_runtime_test_pid, previous_runtime_test_pid)
      restore_app_env(:platform_phx, :sprite_runtime_start_result, previous_runtime_start_result)
      restore_app_env(:platform_phx, :sprite_runtime_stop_result, previous_runtime_stop_result)

      restore_app_env(
        :platform_phx,
        :sprite_runtime_service_state,
        previous_runtime_service_state
      )

      restore_system_env("OPENSEA_API_KEY", previous_api_key)
      restore_system_env("STRIPE_SECRET_KEY", previous_stripe_secret_key)
      restore_system_env("STRIPE_WEBHOOK_SECRET", previous_webhook_secret)
      restore_system_env("STRIPE_BILLING_PRICING_PLAN_ID", previous_pricing_plan_id)
      restore_system_env("STRIPE_BILLING_TOPUP_SUCCESS_URL", previous_topup_success_url)
      restore_system_env("STRIPE_BILLING_TOPUP_CANCEL_URL", previous_topup_cancel_url)
      restore_system_env("STRIPE_RUNTIME_METER_EVENT_NAME", previous_runtime_meter_name)
      restore_system_env("WELCOME_CREDIT_ENABLED", previous_welcome_credit_enabled)
      restore_system_env("WELCOME_CREDIT_LIMIT", previous_welcome_credit_limit)
      restore_system_env("WELCOME_CREDIT_AMOUNT_USD_CENTS", previous_welcome_credit_amount)
      restore_system_env("WELCOME_CREDIT_EXPIRY_DAYS", previous_welcome_credit_expiry)
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
    assert response["billing_account"]["connected"] == false
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

  test "billing setup, top-up, webhook sync, and formation queue a company", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "startline")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()

    billing_response =
      conn
      |> post("/api/agent-platform/billing/setup/checkout", %{claimedLabel: "startline"})
      |> json_response(200)

    assert billing_response["checkout_url"] =~ "billing.stripe.test"
    assert billing_response["checkout_url"] =~ "claimedLabel%3Dstartline"
    assert billing_response["checkout_url"] =~ "billing%3Dsuccess"

    raw_body = stripe_setup_event_body(human.id)

    webhook_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
      |> post("/api/agent-platform/stripe/webhooks", raw_body)

    assert json_response(webhook_conn, 200)["ok"] == true

    job = find_sync_billing_job!("evt_test_checkout")
    assert :ok == perform_job(worker_module(job.worker), job.args)

    account_response =
      conn
      |> get("/api/agent-platform/billing/account")
      |> json_response(200)

    assert account_response["billing_account"]["runtime_credit_balance_usd_cents"] == 500
    assert account_response["billing_account"]["welcome_credit"]["amount_usd_cents"] == 500
    assert account_response["billing_account"]["welcome_credit"]["credit_scope"] == "runtime_only"
    assert account_response["billing_account"]["welcome_credit"]["stripe_sync_status"] == "synced"

    response =
      conn
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "startline"})
      |> json_response(202)

    assert response["agent"]["slug"] == "startline"
    assert response["agent"]["template_key"] == "start"
    assert response["agent"]["status"] == "forming"
    assert response["agent"]["subdomain"]["hostname"] == "startline.regents.sh"
    assert response["agent"]["subdomain"]["active"] == false
    assert response["agent"]["runtime_status"] == "queued"
    assert response["formation"]["status"] == "queued"
    assert response["formation"]["current_step"] == "reserve_claim"

    mint = Repo.get_by!(Mint, label: "startline")
    assert mint.is_in_use == true

    [formation_job] = all_enqueued(worker: RunFormationWorker)
    assert :ok == perform_job(worker_module(formation_job.worker), formation_job.args)

    formation =
      Repo.one!(
        from formation in FormationRun,
          join: agent in assoc(formation, :agent),
          where: agent.slug == "startline"
      )

    assert formation.metadata["workspace_path"] == "/app/company"
    assert formation.metadata["workspace_seed_version"] == "company-workspace-v1"
    assert formation.metadata["hermes_command"] == "/app/bin/hermes-company"
    assert formation.metadata["prompt_template_version"] == "company-workspace-prompt-v1"

    runtime_response =
      conn
      |> get("/api/agent-platform/agents/startline/runtime")
      |> json_response(200)

    assert runtime_response["agent"]["status"] == "published"
    assert runtime_response["agent"]["subdomain"]["active"] == true
    assert runtime_response["runtime"]["sprite"]["owner"] == "regents"
    assert runtime_response["runtime"]["hermes"]["adapter_type"] == "hermes_local"
    assert runtime_response["runtime"]["hermes"]["model"] == "glm-5.1"
    assert runtime_response["billing_account"]["connected"] == true
    assert runtime_response["formation"]["status"] == "succeeded"

    topup_response =
      conn
      |> post("/api/agent-platform/billing/topups/checkout", %{amountUsdCents: 800})
      |> json_response(200)

    assert topup_response["checkout_url"] =~ "runtime-topup"

    topup_body = stripe_topup_event_body(human.id, 800)

    topup_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", stripe_signature(topup_body, "whsec_test"))
      |> post("/api/agent-platform/stripe/webhooks", topup_body)

    assert json_response(topup_conn, 200)["ok"] == true

    topup_job = find_sync_billing_job!("evt_test_topup")
    assert :ok == perform_job(worker_module(topup_job.worker), topup_job.args)

    usage_response =
      conn
      |> get("/api/agent-platform/billing/usage")
      |> json_response(200)

    assert usage_response["usage"]["runtime_credit_balance_usd_cents"] == 1300
    assert usage_response["usage"]["welcome_credit"]["amount_usd_cents"] == 500

    pause_response =
      conn
      |> post("/api/agent-platform/sprites/startline/pause")
      |> json_response(200)

    assert pause_response["sprite"]["desired_runtime_state"] == "paused"

    resume_response =
      conn
      |> post("/api/agent-platform/sprites/startline/resume")
      |> json_response(200)

    assert resume_response["sprite"]["desired_runtime_state"] == "active"
  end

  test "top-up checkout stores the Stripe customer for a fresh billing account", %{conn: conn} do
    human = insert_human!()

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/billing/topups/checkout", %{amountUsdCents: 400})
      |> json_response(200)

    assert response["checkout_url"] =~ "runtime-topup"
    assert response["billing_account"]["customer_id"] == "cus_test_agent_formation"

    billing_account = Repo.get_by!(BillingAccount, human_user_id: human.id)
    assert billing_account.stripe_customer_id == "cus_test_agent_formation"
  end

  test "company creation rolls back the claimed name when the launch job cannot be queued", %{
    conn: conn
  } do
    human = insert_human!()
    insert_claimed_name!(human, "rollback")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    insert_billing_account!(human)
    Application.put_env(:platform_phx, :formation, oban_module: PlatformPhx.ObanInsertErrorFake)

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "rollback"})
      |> json_response(503)

    assert response["statusMessage"] =~ "launch queue is unavailable"

    refute Repo.exists?(
             from agent in PlatformPhx.AgentPlatform.Agent, where: agent.slug == "rollback"
           )

    refute Repo.get_by!(Mint, label: "rollback").is_in_use
  end

  test "company creation rolls back the claimed name when the launch job already exists", %{
    conn: conn
  } do
    human = insert_human!()
    insert_claimed_name!(human, "duplicate")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    insert_billing_account!(human)
    Application.put_env(:platform_phx, :formation, oban_module: PlatformPhx.ObanInsertConflictFake)

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "duplicate"})
      |> json_response(409)

    assert response["statusMessage"] =~ "already queued"

    refute Repo.exists?(
             from agent in PlatformPhx.AgentPlatform.Agent, where: agent.slug == "duplicate"
           )

    refute Repo.get_by!(Mint, label: "duplicate").is_in_use
  end

  test "pause and resume surface sprite runtime failures instead of reporting success", %{
    conn: conn
  } do
    human = insert_human!()
    insert_billing_account!(human)

    agent =
      insert_agent!(human, "runtime-failure", %{
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_status: "ready"
      })

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientRecordingFake
    )

    Application.put_env(
      :platform_phx,
      :sprite_runtime_stop_result,
      {:error, {:external, :sprite, "stop failed"}}
    )

    pause_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/sprites/#{agent.slug}/pause")
      |> json_response(502)

    assert pause_response["statusMessage"] =~ "stop failed"
    assert Repo.get!(PlatformPhx.AgentPlatform.Agent, agent.id).runtime_status == "failed"

    Application.put_env(:platform_phx, :sprite_runtime_stop_result, :ok)

    Application.put_env(
      :platform_phx,
      :sprite_runtime_start_result,
      {:error, {:external, :sprite, "start failed"}}
    )

    resume_response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/sprites/#{agent.slug}/resume")
      |> json_response(502)

    assert resume_response["statusMessage"] =~ "start failed"
    assert Repo.get!(PlatformPhx.AgentPlatform.Agent, agent.id).runtime_status == "failed"
  end

  test "billing-driven runtime changes call sprites.dev promptly", %{conn: _conn} do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    paused_agent =
      insert_agent!(human, "paused-runtime", %{
        desired_runtime_state: "active",
        observed_runtime_state: "paused",
        runtime_status: "paused_for_credits"
      })

    active_agent =
      insert_agent!(human, "active-runtime", %{
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_status: "ready"
      })

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientRecordingFake
    )

    Application.put_env(:platform_phx, :sprite_runtime_test_pid, self())
    Application.put_env(:platform_phx, :sprite_runtime_service_state, "paused")
    Application.put_env(:platform_phx, :sprite_runtime_start_result, :ok)
    Application.put_env(:platform_phx, :sprite_runtime_stop_result, :ok)

    assert :ok ==
             perform_job(PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker, %{
               "event_id" => "evt_runtime_resume",
               "event_type" => "checkout.session.completed",
               "customer_id" => billing_account.stripe_customer_id,
               "subscription_id" => billing_account.stripe_pricing_plan_subscription_id,
               "subscription_status" => "complete",
               "mode" => "payment",
               "metadata" => %{
                 "checkout_kind" => "runtime_topup",
                 "human_user_id" => Integer.to_string(human.id),
                 "billing_account_id" => Integer.to_string(billing_account.id),
                 "amount_usd_cents" => "500"
               }
             })

    paused_sprite_name = "#{paused_agent.slug}-sprite"
    active_sprite_name = "#{active_agent.slug}-sprite"

    assert_receive {:start_service, ^paused_sprite_name, "paperclip"}

    assert :ok ==
             perform_job(PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker, %{
               "event_id" => "evt_runtime_pause",
               "event_type" => "customer.subscription.paused",
               "customer_id" => billing_account.stripe_customer_id,
               "subscription_id" => billing_account.stripe_pricing_plan_subscription_id,
               "subscription_status" => "paused",
               "mode" => "subscription",
               "metadata" => %{
                 "human_user_id" => Integer.to_string(human.id)
               }
             })

    assert_receive {:stop_service, ^paused_sprite_name, "paperclip"}
    assert_receive {:stop_service, ^active_sprite_name, "paperclip"}
  end

  test "billing setup rejects a missing csrf token", %{conn: conn} do
    human = insert_human!()

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> post("/api/agent-platform/billing/setup/checkout", %{})
    end
  end

  test "webhook rejects a stale Stripe signature", %{conn: _conn} do
    raw_body = stripe_topup_event_body(123, 500, 321)
    stale_timestamp = System.system_time(:second) - 601

    webhook_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header(
        "stripe-signature",
        stripe_signature(raw_body, "whsec_test", stale_timestamp)
      )
      |> post("/api/agent-platform/stripe/webhooks", raw_body)

    assert json_response(webhook_conn, 401)["statusMessage"] =~ "outside the allowed window"
  end

  test "formation leaves the company offline when the sprite service is not ready", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "offline")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientPausedFake
    )

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()

    conn
    |> post("/api/agent-platform/billing/setup/checkout", %{claimedLabel: "offline"})
    |> json_response(200)

    raw_body = stripe_setup_event_body(human.id)

    webhook_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
      |> post("/api/agent-platform/stripe/webhooks", raw_body)

    assert json_response(webhook_conn, 200)["ok"] == true

    job = find_sync_billing_job!("evt_test_checkout")
    assert :ok == perform_job(worker_module(job.worker), job.args)

    conn
    |> post("/api/agent-platform/formation/companies", %{claimedLabel: "offline"})
    |> json_response(202)

    agent = Repo.get_by!(PlatformPhx.AgentPlatform.Agent, slug: "offline")

    assert :ok ==
             RunFormationWorker.perform(%Oban.Job{
               args: %{"agent_id" => agent.id},
               attempt: 5,
               max_attempts: 5
             })

    runtime_response =
      conn
      |> get("/api/agent-platform/agents/offline/runtime")
      |> json_response(200)

    assert runtime_response["agent"]["status"] == "failed"
    assert runtime_response["agent"]["subdomain"]["active"] == false
    assert runtime_response["formation"]["status"] == "failed"
    assert runtime_response["formation"]["current_step"] == "verify_runtime"
  end

  test "formation retries runtime readiness before failing and keeps prior launch steps clean", %{
    conn: conn
  } do
    human = insert_human!()
    insert_claimed_name!(human, "warming")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    Application.put_env(
      :platform_phx,
      :sprite_runtime_client,
      PlatformPhx.SpriteRuntimeClientTransitionFake
    )

    Application.put_env(:platform_phx, :sprite_runtime_transition_states, ["paused", "active"])

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()

    conn
    |> post("/api/agent-platform/billing/setup/checkout", %{claimedLabel: "warming"})
    |> json_response(200)

    raw_body = stripe_setup_event_body(human.id)

    webhook_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
      |> post("/api/agent-platform/stripe/webhooks", raw_body)

    assert json_response(webhook_conn, 200)["ok"] == true

    job = find_sync_billing_job!("evt_test_checkout")
    assert :ok == perform_job(worker_module(job.worker), job.args)

    response =
      conn
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "warming"})
      |> json_response(202)

    agent_id = response["agent"]["id"]

    assert match?(
             {:error, {:external, :sprite, _}},
             RunFormationWorker.perform(%Oban.Job{
               args: %{"agent_id" => agent_id},
               attempt: 1,
               max_attempts: 5
             })
           )

    runtime_response =
      conn
      |> get("/api/agent-platform/agents/warming/runtime")
      |> json_response(200)

    assert runtime_response["agent"]["status"] == "forming"
    assert runtime_response["agent"]["subdomain"]["active"] == false
    assert runtime_response["formation"]["status"] == "running"
    assert runtime_response["formation"]["current_step"] == "verify_runtime"

    assert :ok ==
             RunFormationWorker.perform(%Oban.Job{
               args: %{"agent_id" => agent_id},
               attempt: 2,
               max_attempts: 5
             })

    retried_runtime_response =
      conn
      |> get("/api/agent-platform/agents/warming/runtime")
      |> json_response(200)

    assert retried_runtime_response["agent"]["status"] == "published"
    assert retried_runtime_response["agent"]["subdomain"]["active"] == true
    assert retried_runtime_response["formation"]["status"] == "succeeded"

    assert Repo.aggregate(
             from(event in FormationEvent,
               where: event.formation_id == ^runtime_response["formation"]["id"],
               where: event.step == "create_sprite" and event.status == "succeeded"
             ),
             :count,
             :id
           ) == 1
  end

  test "webhook replay does not duplicate a top-up credit", %{conn: _conn} do
    human = insert_human!()
    billing_account = insert_billing_account!(human)
    raw_body = stripe_topup_event_body(human.id, 500, billing_account.id)

    for _ <- 1..2 do
      webhook_conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
        |> post("/api/agent-platform/stripe/webhooks", raw_body)

      assert json_response(webhook_conn, 200)["ok"] == true

      job = find_sync_billing_job!("evt_test_topup")
      assert :ok == perform_job(worker_module(job.worker), job.args)
    end

    account = Repo.get!(BillingAccount, billing_account.id)
    assert account.runtime_credit_balance_usd_cents == 500
  end

  test "top-up replay retries when the follow-up credit-grant job cannot be queued", %{
    conn: _conn
  } do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    args = %{
      "event_id" => "evt_test_topup",
      "event_type" => "checkout.session.completed",
      "customer_id" => billing_account.stripe_customer_id,
      "subscription_id" => nil,
      "subscription_status" => "complete",
      "mode" => "payment",
      "metadata" => %{
        "checkout_kind" => "runtime_topup",
        "human_user_id" => Integer.to_string(human.id),
        "billing_account_id" => Integer.to_string(billing_account.id),
        "amount_usd_cents" => "500"
      }
    }

    %BillingLedgerEntry{}
    |> BillingLedgerEntry.changeset(%{
      billing_account_id: billing_account.id,
      entry_type: "topup",
      amount_usd_cents: 500,
      description: "Runtime credit added through Stripe Checkout.",
      source_ref: "stripe-event:evt_test_topup",
      effective_at: DateTime.utc_now() |> DateTime.truncate(:second),
      stripe_sync_status: "failed",
      stripe_sync_attempt_count: 1
    })
    |> Repo.insert!()

    Application.put_env(
      :platform_phx,
      :runtime_topups,
      oban_module: PlatformPhx.ObanInsertErrorFake
    )

    assert {:error, :queue_unavailable} ==
             perform_job(PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker, args)
  end

  test "billing setup replay does not duplicate the welcome credit", %{conn: conn} do
    human = insert_human!()

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()

    raw_body = stripe_setup_event_body(human.id)

    for _ <- 1..2 do
      webhook_conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", stripe_signature(raw_body, "whsec_test"))
        |> post("/api/agent-platform/stripe/webhooks", raw_body)

      assert json_response(webhook_conn, 200)["ok"] == true

      job = find_sync_billing_job!("evt_test_checkout")
      assert :ok == perform_job(worker_module(job.worker), job.args)
    end

    billing_account =
      conn
      |> get("/api/agent-platform/billing/account")
      |> json_response(200)
      |> get_in(["billing_account"])

    assert billing_account["runtime_credit_balance_usd_cents"] == 500
    assert billing_account["welcome_credit"]["amount_usd_cents"] == 500
    assert Repo.aggregate(WelcomeCreditGrant, :count, :id) == 1
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

  defp insert_agent!(human, slug, attrs) do
    defaults = %{
      owner_human_id: human.id,
      template_key: "start",
      name: "#{String.capitalize(slug)} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: "#{slug}.agent.base.eth",
      ens_fqdn: "#{slug}.regent.eth",
      status: "published",
      public_summary: "Runtime control test company",
      sprite_name: "#{slug}-sprite",
      sprite_service_name: "paperclip",
      stripe_llm_billing_status: "active",
      stripe_customer_id: "cus_test_agent_formation",
      stripe_pricing_plan_subscription_id: "sub_test_agent_formation",
      desired_runtime_state: "active",
      observed_runtime_state: "active",
      runtime_status: "ready"
    }

    %PlatformPhx.AgentPlatform.Agent{}
    |> PlatformPhx.AgentPlatform.Agent.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp request_url(address, collection) do
    "https://api.opensea.io/api/v2/chain/base/account/#{address}/nfts?collection=#{collection}&limit=100"
  end

  defp insert_billing_account!(human) do
    %BillingAccount{}
    |> BillingAccount.changeset(%{
      human_user_id: human.id,
      billing_status: "active",
      stripe_customer_id: unique_external_id("cus_test_agent_formation"),
      stripe_pricing_plan_subscription_id: unique_external_id("sub_test_agent_formation"),
      runtime_credit_balance_usd_cents: 0
    })
    |> Repo.insert!()
  end

  defp unique_external_id(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp stripe_setup_event_body(human_user_id) do
    Jason.encode!(%{
      id: "evt_test_checkout",
      type: "checkout.session.completed",
      data: %{
        object: %{
          customer: "cus_test_agent_formation",
          subscription: "sub_test_agent_formation",
          mode: "subscription",
          status: "active",
          metadata: %{
            "checkout_kind" => "billing_setup",
            "human_user_id" => Integer.to_string(human_user_id)
          }
        }
      }
    })
  end

  defp stripe_topup_event_body(human_user_id, amount_usd_cents, billing_account_id \\ nil) do
    metadata =
      %{
        "checkout_kind" => "runtime_topup",
        "human_user_id" => Integer.to_string(human_user_id),
        "amount_usd_cents" => Integer.to_string(amount_usd_cents)
      }
      |> maybe_put_billing_account_id(billing_account_id)

    Jason.encode!(%{
      id: "evt_test_topup",
      type: "checkout.session.completed",
      data: %{
        object: %{
          customer: "cus_test_agent_formation",
          mode: "payment",
          status: "complete",
          metadata: metadata
        }
      }
    })
  end

  defp maybe_put_billing_account_id(metadata, nil), do: metadata

  defp maybe_put_billing_account_id(metadata, id),
    do: Map.put(metadata, "billing_account_id", Integer.to_string(id))

  defp stripe_signature(raw_body, secret, timestamp \\ System.system_time(:second)) do
    timestamp = Integer.to_string(timestamp)

    signed =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signed}"
  end

  defp worker_module(worker) when is_atom(worker), do: worker
  defp worker_module(worker) when is_binary(worker), do: Module.concat([worker])

  defp find_sync_billing_job!(event_id) do
    all_enqueued(worker: PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker)
    |> Enum.find(fn job -> job.args["event_id"] == event_id end)
    |> case do
      nil -> flunk("expected Stripe billing job for #{event_id}")
      job -> job
    end
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end
end
