defmodule PlatformPhxWeb.Api.AgentFormationControllerTest do
  use PlatformPhxWeb.ConnCase, async: false
  use Oban.Testing, repo: PlatformPhx.Repo
  import Ecto.Query

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.Artifact
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.FormationEvent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.LlmUsageEvent
  alias PlatformPhx.AgentPlatform.SpriteAdminAction
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.StripeEvent
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
    previous_sprites_client = Application.get_env(:platform_phx, :runtime_registry_sprites_client)

    previous_credit_grant_result =
      Application.get_env(:platform_phx, :stripe_fake_credit_grant_result)

    previous_runtime_transition_states =
      Application.get_env(:platform_phx, :sprite_runtime_transition_states)

    previous_runtime_topups = Application.get_env(:platform_phx, :runtime_topups, [])
    previous_formation = Application.get_env(:platform_phx, :formation, [])

    previous_agent_formation_enabled =
      Application.get_env(:platform_phx, :agent_formation_enabled)

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
    previous_agent_formation_enabled_env = System.get_env("AGENT_FORMATION_ENABLED")

    Application.put_env(:platform_phx, :opensea_http_client, PlatformPhx.OpenSeaFakeClient)
    Application.put_env(:platform_phx, :opensea_fake_responses, %{})
    Application.put_env(:platform_phx, :stripe_billing_client, PlatformPhx.StripeLlmFakeClient)
    Application.put_env(:platform_phx, :stripe_fake_credit_grant_result, :ok)
    Application.put_env(:platform_phx, :agent_formation_enabled, true)

    Application.put_env(
      :platform_phx,
      :agent_platform_sprite_runner,
      PlatformPhx.SpriteRunnerFake
    )

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
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
    System.delete_env("AGENT_FORMATION_ENABLED")
    OpenSea.clear_cache()

    on_exit(fn ->
      restore_app_env(:platform_phx, :opensea_http_client, previous_client)
      restore_app_env(:platform_phx, :opensea_fake_responses, previous_responses)
      restore_app_env(:platform_phx, :stripe_billing_client, previous_stripe_client)
      restore_app_env(:platform_phx, :agent_platform_sprite_runner, previous_sprite_runner)
      restore_app_env(:platform_phx, :runtime_registry_sprites_client, previous_sprites_client)

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
      restore_app_env(:platform_phx, :agent_formation_enabled, previous_agent_formation_enabled)
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
      restore_system_env("AGENT_FORMATION_ENABLED", previous_agent_formation_enabled_env)
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
    assert response["readiness"]["ready"] == false
    assert get_in(response, ["readiness", "blocked_step", "key"]) == "identity"
    assert length(response["readiness"]["steps"]) == 8

    assert get_in(response, ["access_eligibility", "rule"]) ==
             "hold_approved_collection_nft_and_claim_name"

    assert get_in(response, ["access_eligibility", "eligible"]) == false
    assert get_in(response, ["formation_state", "state"]) == "blocked"
    assert get_in(response, ["billing_state", "state"]) == "trial"
    assert get_in(response, ["runtime_cost_state", "phase"]) == "unavailable"
    assert get_in(response, ["blockers", Access.at(0), "key"]) == "identity"
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
    assert get_in(response, ["access_eligibility", "approved_collection_nft"]) == true
    assert get_in(response, ["access_eligibility", "claimed_name_ready"]) == true
    assert get_in(response, ["access_eligibility", "eligible"]) == true
    assert get_in(response, ["collections", "animata1"]) == [7]
    assert Enum.map(response["available_claims"], & &1["label"]) == ["tempo"]
    assert hd(response["available_claims"])["in_use"] == false
    assert get_in(response, ["formation_state", "state"]) == "blocked"
    assert get_in(response, ["billing_state", "state"]) == "trial"
    assert get_in(response, ["runtime_cost_state", "paused_at_zero"]) == false
    assert get_in(response, ["blockers", Access.at(0), "key"]) == "billing"
    assert get_in(response, ["readiness", "blocked_step", "key"]) == "billing"

    assert get_in(response, ["readiness", "blocked_step", "message"]) ==
             "Activate billing before opening a company."
  end

  test "formation exposes runtime cost phase during the free day", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "free-day")
    insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 500})

    free_until =
      DateTime.utc_now()
      |> DateTime.add(3_600, :second)
      |> DateTime.truncate(:second)

    insert_agent!(human, "free-day", %{sprite_free_until: free_until})

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

    assert get_in(response, ["billing_state", "state"]) == "free_day"
    assert get_in(response, ["runtime_cost_state", "phase"]) == "free_day"
    assert get_in(response, ["runtime_cost_state", "hourly_cost_usd_cents"]) == 25

    assert get_in(response, ["runtime_cost_state", "free_day_ends_at"]) ==
             DateTime.to_iso8601(free_until)

    assert get_in(response, ["runtime_cost_state", "prepaid_drawdown_state"]) == "free_day"
    assert get_in(response, ["runtime_cost_state", "next_pause_threshold_usd_cents"]) == 0

    assert get_in(response, ["runtime_cost_state", "pause_targets", Access.at(0), "slug"]) ==
             "free-day"
  end

  test "formation keeps billing state separate before company opening", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "funded")
    insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 500})

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

    assert get_in(response, ["billing_state", "state"]) == "prepaid"
    assert get_in(response, ["billing_state", "runtime_allowed"]) == true
    assert get_in(response, ["formation_state", "state"]) == "pending"
    assert get_in(response, ["runtime_cost_state", "phase"]) == "unavailable"
  end

  test "formation doctor explains the current blocker", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "doctor")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "7"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/formation/doctor")
      |> json_response(200)

    assert response["doctor"]["status"] == "blocked"
    assert response["doctor"]["summary"] == "Blocked: Activate billing before opening a company."
    assert Enum.map(response["doctor"]["blockers"], & &1["key"]) == ["billing"]

    assert Enum.find(response["doctor"]["checks"], &(&1["key"] == "billing"))["status"] ==
             "needs_action"
  end

  test "projection exposes canonical company runtime billing formation and profile state", %{
    conn: conn
  } do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    agent =
      insert_agent!(human, "projection", %{
        sprite_free_until: nil,
        runtime_status: "ready",
        observed_runtime_state: "active"
      })

    insert_artifact!(agent, %{title: "Public update"})

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/projection")
      |> json_response(200)

    projection = response["projection"]
    assert projection["billing_account"]["runtime_credit_balance_usd_cents"] == 0
    assert projection["billing_usage"]["runtime_credit_balance_usd_cents"] == 0

    assert get_in(projection, ["formation", "owned_companies", Access.at(0), "slug"]) ==
             "projection"

    company_projection = hd(projection["companies"])
    assert get_in(company_projection, ["company", "slug"]) == "projection"
    assert get_in(company_projection, ["runtime", "sprite", "name"]) == agent.sprite_name

    assert get_in(company_projection, ["public_profile", "feed", Access.at(0), "title"]) ==
             "Public update"

    assert get_in(projection, ["public_profiles", Access.at(0), "slug"]) == "projection"

    assert Repo.get!(BillingAccount, billing_account.id).runtime_credit_balance_usd_cents == 0
  end

  test "formation only offers claimed names that are not already in use", %{conn: conn} do
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

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/formation")
      |> json_response(200)

    assert Enum.map(response["available_claims"], & &1["label"]) == ["fresh"]

    claimed_by_label = Map.new(response["claimed_names"], &{&1["label"], &1["in_use"]})

    assert claimed_by_label == %{
             "attached" => true,
             "forming" => true,
             "fresh" => false,
             "marked" => true
           }
  end

  test "company opening writes are unavailable when company opening is paused", %{conn: conn} do
    Application.put_env(:platform_phx, :agent_formation_enabled, false)

    human = insert_human!()

    conn =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()

    unavailable_message = "Hosted company opening is not available right now."

    for {path, payload} <- [
          {"/api/agent-platform/billing/setup/checkout", %{claimedLabel: "quiet"}},
          {"/api/agent-platform/billing/topups/checkout", %{amountUsdCents: 800}},
          {"/api/agent-platform/formation/companies", %{claimedLabel: "quiet"}},
          {"/api/agent-platform/sprites/quiet/pause", %{}},
          {"/api/agent-platform/sprites/quiet/resume", %{}}
        ] do
      response =
        conn
        |> post(path, payload)
        |> json_response(503)

      assert response["error"]["message"] == unavailable_message
    end
  end

  test "billing setup requires an eligible pass before creating a billing account", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "quiet")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/billing/setup/checkout", %{claimedLabel: "quiet"})
      |> json_response(403)

    assert response["error"]["message"] ==
             "You need Animata I, Regent Animata II, or Regents Club to create a company"

    refute Repo.get_by(BillingAccount, human_user_id: human.id)
  end

  test "billing setup requires a selected claimed name before creating a billing account", %{
    conn: conn
  } do
    human = insert_human!()

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/billing/setup/checkout", %{})
      |> json_response(400)

    assert response["error"]["message"] == "Claim a name before starting Agent Formation"
    refute Repo.get_by(BillingAccount, human_user_id: human.id)
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
        from(formation in FormationRun,
          join: agent in assoc(formation, :agent),
          where: agent.slug == "startline"
        )
      )

    assert formation.metadata["workspace_path"] == "/app/company"
    assert formation.metadata["workspace_seed_version"] == "company-workspace-v1"
    assert formation.metadata["workspace_ref"] == "main"
    assert formation.metadata["hermes_command"] == "/app/bin/hermes-company"
    assert formation.metadata["hermes_agent_ref"] == "main"
    assert formation.metadata["prompt_template_version"] == "company-workspace-prompt-v1"

    runtime_response =
      conn
      |> get("/api/agent-platform/agents/startline/runtime")
      |> json_response(200)

    assert runtime_response["agent"]["status"] == "published"
    assert runtime_response["agent"]["subdomain"]["active"] == true
    assert runtime_response["runtime"]["sprite"]["owner"] == "regents"
    assert runtime_response["runtime"]["workspace"]["workspace_path"] == "/app/company"

    assert runtime_response["runtime"]["workspace"]["workspace_seed_version"] ==
             "company-workspace-v1"

    assert runtime_response["runtime"]["workspace"]["url"] == "https://startline.sprites.dev"
    assert runtime_response["runtime"]["workspace"]["http_port"] == 3000
    assert runtime_response["runtime"]["hermes"]["adapter_type"] == "stock"
    assert runtime_response["runtime"]["hermes"]["model"] == "glm-5.1"
    assert runtime_response["runtime"]["hermes"]["command"] == "/app/bin/hermes-company"

    assert runtime_response["runtime"]["hermes"]["prompt_template_version"] ==
             "company-workspace-prompt-v1"

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

    sprite_actions =
      Repo.all(
        from(action in SpriteAdminAction,
          where: action.agent_id == ^formation.agent_id,
          order_by: [asc: action.created_at],
          select: {action.action, action.status, action.actor_type, action.source}
        )
      )

    assert {"create_sprite", "succeeded", "system", "run_formation_worker"} in sprite_actions

    assert {"bootstrap_workspace", "succeeded", "system", "run_formation_worker"} in sprite_actions

    assert {"pause_runtime", "succeeded", "human_user", "formation_api_pause"} in sprite_actions
    assert {"resume_runtime", "succeeded", "human_user", "formation_api_resume"} in sprite_actions
  end

  test "billing setup hides missing Stripe setup details", %{conn: conn} do
    human = insert_human!()
    insert_claimed_name!(human, "quiet")

    Application.put_env(:platform_phx, :opensea_fake_responses, %{
      request_url(@address, "animata") =>
        {:ok, %{"nfts" => [%{"collection" => "animata", "identifier" => "3"}], "next" => nil}},
      request_url(@address, "regent-animata-ii") => {:ok, %{"nfts" => [], "next" => nil}},
      request_url(@address, "regents-club") => {:ok, %{"nfts" => [], "next" => nil}}
    })

    System.delete_env("STRIPE_SECRET_KEY")

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/billing/setup/checkout", %{claimedLabel: "quiet"})
      |> json_response(503)

    assert response["error"]["message"] == "Billing is unavailable right now."
    refute response["error"]["message"] =~ "STRIPE_SECRET_KEY"
    refute response["error"]["message"] =~ "Server missing"
    refute_public_leak(response["error"]["message"])
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

  test "billing usage reports runtime spend and model spend totals", %{conn: conn} do
    human = insert_human!()
    billing_account = insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 125})

    agent =
      insert_agent!(human, "metered", %{
        sprite_metering_status: "paid"
      })

    reported_at = DateTime.utc_now() |> DateTime.truncate(:second)

    %SpriteUsageRecord{}
    |> SpriteUsageRecord.changeset(%{
      billing_account_id: billing_account.id,
      agent_id: agent.id,
      meter_key: "metered-hour",
      usage_seconds: 3600,
      amount_usd_cents: 25,
      window_started_at:
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second),
      window_ended_at: DateTime.utc_now() |> DateTime.truncate(:second),
      status: "reported",
      stripe_reported_at: reported_at
    })
    |> Repo.insert!()

    %LlmUsageEvent{}
    |> LlmUsageEvent.changeset(%{
      agent_id: agent.id,
      human_user_id: human.id,
      external_run_id: "run-metered-1",
      provider: "openai",
      model: "gpt-5.4-mini",
      input_tokens: 1200,
      output_tokens: 320,
      amount_usd_cents: 46,
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> get("/api/agent-platform/billing/usage")
      |> json_response(200)

    assert response["usage"]["runtime_spend_usd_cents"] == 25
    assert response["usage"]["llm_spend_usd_cents"] == 46
    assert response["usage"]["prepaid_drawdown_state"] == "drawing_down"
    assert response["usage"]["last_usage_sync_at"] == DateTime.to_iso8601(reported_at)
    assert response["usage"]["next_pause_threshold_usd_cents"] == 0
    assert get_in(response, ["usage", "pause_targets", Access.at(0), "slug"]) == "metered"
    assert get_in(response, ["usage", "companies", Access.at(0), "runtime_spend_usd_cents"]) == 25
    assert get_in(response, ["usage", "companies", Access.at(0), "llm_spend_usd_cents"]) == 46

    assert get_in(response, ["usage", "companies", Access.at(0), "last_usage_sync_at"]) ==
             DateTime.to_iso8601(reported_at)

    assert get_in(response, ["usage", "companies", Access.at(0), "will_pause_at_zero"]) == true
  end

  test "workspace seed reads the env file and preserves an existing workspace" do
    tmp_dir = unique_tmp_dir!("company-workspace-seed")
    workspace_path = Path.join(tmp_dir, "company")
    hermes_command = Path.join([tmp_dir, "bin", "hermes-company"])
    env_file_path = Path.join(tmp_dir, ".env")

    script_path =
      "/Users/sean/Documents/regent/platform/priv/agent_formation/hermes-workspace/seed_company_workspace.mjs"

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    File.write!(
      env_file_path,
      """
      FORMATION_SLUG=seeded-company
      FORMATION_WORKSPACE_PATH=#{workspace_path}
      FORMATION_HERMES_COMMAND=#{hermes_command}
      FORMATION_TEMPLATE_KEY=start
      FORMATION_TEMPLATE_PUBLIC_NAME=Start Regent
      FORMATION_TEMPLATE_SUMMARY=Start template summary
      FORMATION_TEMPLATE_COMPANY_PURPOSE=Run one company workspace.
      FORMATION_TEMPLATE_WORKER_ROLE=Primary worker role.
      FORMATION_TEMPLATE_SERVICES=[{"name":"Start plan","summary":"Turn an idea into a plan.","price_label":"$1.05 / call"}]
      FORMATION_TEMPLATE_CONNECTION_DEFAULTS=[{"display_name":"X account","status":"action_required"}]
      FORMATION_TEMPLATE_RECOMMENDED_NETWORK_DOMAINS=["github.com","x.com"]
      FORMATION_TEMPLATE_CHECKPOINT_MOMENTS=["After Hermes Workspace is reachable on the Sprite"]
      """
    )

    {first_output, 0} = System.cmd("node", ["--env-file=.env", script_path], cd: tmp_dir)
    first_payload = Jason.decode!(String.trim(first_output))

    assert first_payload["workspace_path"] == workspace_path
    assert first_payload["hermes_command"] == hermes_command
    assert hermes_command in first_payload["created_files"]
    assert File.read!(hermes_command) =~ "export PATH=\"$HOME/.local/bin:$PATH\""
    assert File.read!(hermes_command) =~ "exec hermes \"$@\""

    assert File.read!(Path.join(workspace_path, "HOME.md")) =~
             "# seeded-company company workspace"

    assert File.read!(Path.join(workspace_path, "PLATFORM_CONTEXT.md")) =~ "Start Regent"

    File.write!(Path.join(workspace_path, "HOME.md"), "# preserved workspace\n")
    File.write!(hermes_command, "#!/usr/bin/env sh\necho custom-wrapper\n")

    {second_output, 0} = System.cmd("node", ["--env-file=.env", script_path], cd: tmp_dir)
    second_payload = Jason.decode!(String.trim(second_output))

    assert second_payload["created_files"] == []
    assert File.read!(Path.join(workspace_path, "HOME.md")) == "# preserved workspace\n"
    assert File.read!(hermes_command) == "#!/usr/bin/env sh\necho custom-wrapper\n"
  end

  test "public feed only returns public artifacts", %{conn: conn} do
    human = insert_human!()
    agent = insert_agent!(human, "feedline", %{})

    insert_artifact!(agent, %{
      title: "Public safe artifact",
      summary: "Safe output",
      url: "https://example.com/safe-output",
      visibility: "public"
    })

    insert_artifact!(agent, %{
      title: "Private artifact",
      summary: "Private output",
      url: "https://example.com/private-output",
      visibility: "private"
    })

    response =
      conn
      |> get("/api/agent-platform/agents/feedline/feed")
      |> json_response(200)

    assert response["ok"] == true
    assert response["agent"]["slug"] == "feedline"

    assert response["feed"]
           |> Enum.map(& &1["title"])
           |> Enum.sort() == ["Public safe artifact"]

    safe_artifact = Enum.find(response["feed"], &(&1["title"] == "Public safe artifact"))

    assert safe_artifact["url"] == "https://example.com/safe-output"
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

    insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 500})
    Application.put_env(:platform_phx, :formation, oban_module: PlatformPhx.ObanInsertErrorFake)

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "rollback"})
      |> json_response(503)

    assert response["error"]["message"] =~ "launch queue is unavailable"

    refute Repo.exists?(
             from(agent in PlatformPhx.AgentPlatform.Agent, where: agent.slug == "rollback")
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

    insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 500})

    Application.put_env(:platform_phx, :formation,
      oban_module: PlatformPhx.ObanInsertConflictFake
    )

    response =
      conn
      |> init_test_session(%{current_human_id: human.id})
      |> put_csrf_token()
      |> post("/api/agent-platform/formation/companies", %{claimedLabel: "duplicate"})
      |> json_response(409)

    assert response["error"]["message"] =~ "already queued"

    refute Repo.exists?(
             from(agent in PlatformPhx.AgentPlatform.Agent, where: agent.slug == "duplicate")
           )

    refute Repo.get_by!(Mint, label: "duplicate").is_in_use
  end

  test "pause and resume hide sprite runtime failure details", %{
    conn: conn
  } do
    human = insert_human!()
    insert_billing_account!(human, %{runtime_credit_balance_usd_cents: 500})

    agent =
      insert_agent!(human, "runtime-failure", %{
        desired_runtime_state: "active",
        observed_runtime_state: "active",
        runtime_status: "ready"
      })

    Application.put_env(
      :platform_phx,
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
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

    assert pause_response["error"]["message"] == "Company controls are unavailable right now."
    refute_public_leak(pause_response["error"]["message"])
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

    assert resume_response["error"]["message"] == "Company controls are unavailable right now."
    refute_public_leak(resume_response["error"]["message"])
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
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    Application.put_env(:platform_phx, :sprite_runtime_test_pid, self())
    Application.put_env(:platform_phx, :sprite_runtime_service_state, "paused")
    Application.put_env(:platform_phx, :sprite_runtime_start_result, :ok)
    Application.put_env(:platform_phx, :sprite_runtime_stop_result, :ok)

    assert :ok ==
             perform_job(
               PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker,
               worker_args_for_stripe_event(%{
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
             )

    paused_sprite_name = "#{paused_agent.slug}-sprite"
    active_sprite_name = "#{active_agent.slug}-sprite"

    assert_receive {:start_service, ^paused_sprite_name, "hermes-workspace"}

    assert :ok ==
             perform_job(
               PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker,
               worker_args_for_stripe_event(%{
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
             )

    assert_receive {:stop_service, ^paused_sprite_name, "hermes-workspace"}
    assert_receive {:stop_service, ^active_sprite_name, "hermes-workspace"}
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

    assert json_response(webhook_conn, 401)["error"]["message"] =~ "outside the allowed window"
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
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
    )

    Application.put_env(:platform_phx, :sprite_runtime_service_state, "paused")

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
      :runtime_registry_sprites_client,
      PlatformPhx.RuntimeRegistrySpritesClientFake
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
    assert Repo.aggregate(StripeEvent, :count, :id) == 1
  end

  test "top-up replay retries when the follow-up credit-grant job cannot be queued", %{
    conn: _conn
  } do
    human = insert_human!()
    billing_account = insert_billing_account!(human)

    stripe_event =
      insert_stripe_event!(%{
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
      })

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
             perform_job(PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker, %{
               "stripe_event_id" => stripe_event.id
             })
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
    assert Repo.aggregate(StripeEvent, :count, :id) == 1

    assert length(all_enqueued(worker: PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker)) ==
             1
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

  defp insert_claimed_name!(human, label, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    mint_attrs = %{
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
    |> Mint.changeset(Map.merge(mint_attrs, attrs))
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
      sprite_service_name: "hermes-workspace",
      stripe_llm_billing_status: "active",
      stripe_customer_id: "cus_test_agent_formation",
      stripe_pricing_plan_subscription_id: "sub_test_agent_formation",
      desired_runtime_state: "active",
      observed_runtime_state: "active",
      runtime_status: "ready"
    }

    agent_attrs = Map.merge(defaults, attrs)

    company =
      %Company{}
      |> Company.changeset(%{
        owner_human_id: human.id,
        name: agent_attrs.name,
        slug: agent_attrs.slug,
        claimed_label: agent_attrs.claimed_label,
        status: agent_attrs.status,
        public_summary: agent_attrs.public_summary
      })
      |> Repo.insert!()

    %PlatformPhx.AgentPlatform.Agent{}
    |> PlatformPhx.AgentPlatform.Agent.changeset(Map.put(agent_attrs, :company_id, company.id))
    |> Repo.insert!()
  end

  defp insert_artifact!(agent, attrs) do
    defaults = %{
      agent_id: agent.id,
      title: "Artifact",
      summary: "Artifact summary",
      visibility: "public",
      published_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %Artifact{}
    |> Artifact.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp request_url(address, collection) do
    "https://api.opensea.io/api/v2/chain/base/account/#{address}/nfts?collection=#{collection}&limit=100"
  end

  defp insert_billing_account!(human, attrs \\ %{}) do
    %BillingAccount{}
    |> BillingAccount.changeset(
      Map.merge(
        %{
          human_user_id: human.id,
          billing_status: "active",
          stripe_customer_id: unique_external_id("cus_test_agent_formation"),
          stripe_pricing_plan_subscription_id: unique_external_id("sub_test_agent_formation"),
          runtime_credit_balance_usd_cents: 0
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp unique_external_id(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp unique_tmp_dir!(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive, :monotonic])}")
  end

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
    stripe_event = Repo.get_by!(StripeEvent, event_id: event_id)

    all_enqueued(worker: PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker)
    |> Enum.find(fn job -> job.args["stripe_event_id"] == stripe_event.id end)
    |> case do
      nil -> flunk("expected Stripe billing job for #{event_id}")
      job -> job
    end
  end

  defp insert_stripe_event!(event) do
    %StripeEvent{}
    |> StripeEvent.changeset(%{
      event_id: event["event_id"],
      event_type: event["event_type"],
      customer_id: event["customer_id"],
      subscription_id: event["subscription_id"],
      subscription_status: event["subscription_status"],
      mode: event["mode"],
      metadata: event["metadata"] || %{},
      processing_status: "queued"
    })
    |> Repo.insert!()
  end

  defp worker_args_for_stripe_event(event) do
    stripe_event = insert_stripe_event!(event)
    %{"stripe_event_id" => stripe_event.id}
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp refute_public_leak(message) do
    refute message =~ "stop failed"
    refute message =~ "start failed"
    refute message =~ "%{"
    refute message =~ "{:"
  end

  defp put_csrf_token(conn) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_session("_csrf_token", Plug.CSRFProtection.dump_state())
    |> put_req_header("x-csrf-token", token)
  end
end
