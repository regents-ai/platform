defmodule PlatformPhx.AgentPlatform.Formation do
  @moduledoc false

  import Ecto.Query, warn: false
  require Logger

  alias Ecto.Multi
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Billing
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.Connection
  alias PlatformPhx.AgentPlatform.FormationProgress
  alias PlatformPhx.AgentPlatform.Formation.Readiness
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.RuntimeControl
  alias PlatformPhx.AgentPlatform.Service
  alias PlatformPhx.AgentPlatform.StripeBilling
  alias PlatformPhx.AgentPlatform.StripeEvent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.AgentPlatform.Workers.RunFormationWorker
  alias PlatformPhx.AgentPlatform.Workers.SyncStripeBillingWorker
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.PublicErrors
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhxWeb.Endpoint
  alias PlatformPhx.XMTPMirror.Rooms, as: XMTPRooms
  alias Oban

  @default_template_key "start"
  @bootstrap_script_version "agent-formation-v1"
  @approved_collection_keys ["animata1", "animata2", "animataPass"]
  @runtime_hourly_cost_usd_cents 25

  def formation_payload(nil) do
    billing_account = Billing.account_payload(nil, [])
    holdings = empty_holdings()

    readiness =
      Readiness.payload(%{
        authenticated: false,
        wallet_connected?: false,
        eligible: false,
        available_claims: [],
        billing_account: billing_account,
        template_ready?: template_ready?(),
        owned_companies: [],
        active_formations: []
      })

    blockers = formation_blockers(readiness, [], billing_account)

    {:ok,
     %{
       ok: true,
       authenticated: false,
       wallet_address: nil,
       eligible: false,
       access_eligibility: access_eligibility_payload(holdings, false, [], []),
       formation_state: formation_state_payload(readiness, [], [], blockers),
       billing_state: billing_state_payload(billing_account, []),
       runtime_cost_state: runtime_cost_state_payload(billing_account, []),
       blockers: blockers,
       collections: holdings,
       claimed_names: [],
       available_claims: [],
       billing_account: billing_account,
       owned_companies: [],
       active_formations: [],
       readiness: readiness
     }}
  end

  def formation_payload(%HumanUser{} = human) do
    with {:ok, holdings} <- AgentPlatform.holdings_for_human(human) do
      claimed_names = AgentPlatform.claimed_names_for_human(human)
      companies = AgentPlatform.list_owned_agents(human)
      billing_account = Billing.get_account(human)
      available_claims = Enum.reject(claimed_names, &formation_claim_used?/1)
      billing_account_payload = Billing.account_payload(billing_account, companies)

      active_formations =
        companies
        |> Enum.map(& &1.formation_run)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&serialize_formation/1)

      wallet_connected? = AgentPlatform.linked_wallet_addresses(human) != []

      readiness =
        Readiness.payload(%{
          authenticated: true,
          wallet_connected?: wallet_connected?,
          eligible: AgentPlatform.eligible_holdings?(holdings),
          available_claims: available_claims,
          billing_account: billing_account_payload,
          template_ready?: template_ready?(),
          owned_companies: companies,
          active_formations: active_formations
        })

      blockers = formation_blockers(readiness, companies, billing_account_payload)

      {:ok,
       %{
         ok: true,
         authenticated: true,
         wallet_address: AgentPlatform.current_wallet_address(human),
         eligible: AgentPlatform.eligible_holdings?(holdings),
         access_eligibility:
           access_eligibility_payload(
             holdings,
             wallet_connected?,
             claimed_names,
             available_claims
           ),
         formation_state:
           formation_state_payload(readiness, companies, active_formations, blockers),
         billing_state: billing_state_payload(billing_account_payload, companies),
         runtime_cost_state: runtime_cost_state_payload(billing_account_payload, companies),
         blockers: blockers,
         collections: holdings,
         claimed_names: claimed_names,
         available_claims: available_claims,
         billing_account: billing_account_payload,
         owned_companies: AgentPlatform.serialize_agents(companies, :private),
         active_formations: active_formations,
         readiness: readiness
       }}
    end
  end

  def doctor_payload(nil),
    do: {:error, {:unauthorized, "Sign in before reading formation doctor"}}

  def doctor_payload(%HumanUser{} = human) do
    with {:ok, payload} <- formation_payload(human) do
      {:ok, %{ok: true, doctor: doctor_from_formation(payload)}}
    end
  end

  def projection_payload(nil),
    do: {:error, {:unauthorized, "Sign in before reading Platform state"}}

  def projection_payload(%HumanUser{} = human) do
    with {:ok, formation} <- formation_payload(human) do
      companies = AgentPlatform.list_owned_agents(human)
      billing_account = Billing.get_account(human)
      billing_payload = Billing.account_payload(billing_account, companies)

      usage_payload =
        case billing_account do
          %BillingAccount{} = account -> Billing.usage_payload(account, companies)
          nil -> Billing.usage_payload(%BillingAccount{}, companies)
        end

      private_companies_by_id =
        companies
        |> AgentPlatform.serialize_agents(:private)
        |> Map.new(&{&1.id, &1})

      public_companies_by_id =
        companies
        |> AgentPlatform.serialize_agents(:public)
        |> Map.new(&{&1.id, &1})

      company_projections =
        Enum.map(companies, fn agent ->
          %{
            company: Map.fetch!(private_companies_by_id, agent.id),
            runtime: AgentPlatform.runtime_payload_map(agent, billing_account),
            formation: serialize_formation(agent.formation_run),
            public_profile: Map.fetch!(public_companies_by_id, agent.id)
          }
        end)

      {:ok,
       %{
         ok: true,
         projection: %{
           formation: formation,
           billing_account: billing_payload,
           billing_usage: usage_payload,
           companies: company_projections,
           public_profiles: Enum.map(companies, &Map.fetch!(public_companies_by_id, &1.id))
         }
       }}
    end
  end

  def start_billing_setup_checkout(human, attrs \\ %{})

  def start_billing_setup_checkout(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before setting up billing"}}

  def start_billing_setup_checkout(%HumanUser{} = human, attrs) when is_map(attrs) do
    with :ok <- require_agent_formation_enabled(),
         :ok <- ensure_wallet_connected(human),
         {:ok, holdings} <- AgentPlatform.holdings_for_human(human),
         :ok <- ensure_eligible_holdings(holdings),
         {:ok, _mint} <- require_available_claimed_name(human, attrs),
         {:ok, billing_account} <- Billing.ensure_account(human),
         {:ok, checkout_urls} <- build_billing_setup_checkout_urls(attrs),
         {:ok, checkout} <-
           StripeBilling.create_billing_setup_checkout_session(
             billing_account,
             human.id,
             success_url: checkout_urls.success_url,
             cancel_url: checkout_urls.cancel_url
           ),
         {:ok, updated_account} <-
           billing_account
           |> BillingAccount.changeset(%{
             billing_status: "checkout_open",
             stripe_customer_id: checkout.customer_id || billing_account.stripe_customer_id
           })
           |> Repo.update() do
      {:ok,
       %{
         ok: true,
         checkout_url: checkout.url,
         billing_account: Billing.account_payload(updated_account)
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  def create_company(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before starting Agent Formation"}}

  def create_company(%HumanUser{} = human, attrs) when is_map(attrs) do
    with :ok <- require_agent_formation_enabled(),
         :ok <- ensure_wallet_connected(human),
         {:ok, holdings} <- AgentPlatform.holdings_for_human(human),
         :ok <- ensure_eligible_holdings(holdings),
         {:ok, billing_account} <- require_active_billing_account(human),
         {:ok, template} <- require_customer_template(),
         {:ok, mint} <- require_available_claimed_name(human, attrs),
         false <- slug_taken?(mint.label),
         {:ok, %{agent: agent, formation: formation}} <-
           create_company_records(human, billing_account, mint, template) do
      reloaded = AgentPlatform.get_owned_agent(human, agent.slug)

      {:accepted,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(reloaded, :private),
         formation: serialize_formation(formation)
       }}
    else
      true -> {:error, {:conflict, "That claimed name is already active as a company"}}
      {:error, _reason} = error -> error
    end
  end

  def runtime_payload(nil, _slug),
    do: {:error, {:unauthorized, "Sign in before reading formation status"}}

  def runtime_payload(%HumanUser{} = human, slug) when is_binary(slug) do
    case AgentPlatform.get_owned_agent(human, slug) do
      %Agent{} = agent ->
        billing_account = Billing.get_account(human)

        {:ok,
         %{
           ok: true,
           agent: AgentPlatform.serialize_agent(agent, :private),
           runtime: AgentPlatform.runtime_payload_map(agent, billing_account),
           billing_account: Billing.account_payload(billing_account, [agent]),
           formation: serialize_formation(agent.formation_run)
         }}

      nil ->
        {:error, {:not_found, "Company not found"}}
    end
  end

  def billing_account_payload(nil),
    do: {:error, {:unauthorized, "Sign in before reading billing"}}

  def billing_account_payload(%HumanUser{} = human) do
    companies = AgentPlatform.list_owned_agents(human)
    billing_account = Billing.get_account(human)

    {:ok,
     %{
       ok: true,
       billing_account: Billing.account_payload(billing_account, companies)
     }}
  end

  def billing_usage(nil),
    do: {:error, {:unauthorized, "Sign in before reading billing usage"}}

  def billing_usage(%HumanUser{} = human) do
    companies = AgentPlatform.list_owned_agents(human)
    billing_account = Billing.get_account(human)

    usage =
      case billing_account do
        %BillingAccount{} = account -> Billing.usage_payload(account, companies)
        nil -> Billing.usage_payload(%BillingAccount{}, companies)
      end

    {:ok, %{ok: true, usage: usage}}
  end

  def start_billing_topup_checkout(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before adding runtime credit"}}

  def start_billing_topup_checkout(%HumanUser{} = human, attrs) when is_map(attrs) do
    with :ok <- require_agent_formation_enabled(),
         amount when is_integer(amount) and amount > 0 <-
           normalize_positive_integer(Map.get(attrs, "amountUsdCents")),
         {:ok, billing_account} <- Billing.ensure_account(human),
         {:ok, checkout} <- StripeBilling.create_topup_checkout_session(billing_account, amount),
         {:ok, updated_account} <-
           billing_account
           |> BillingAccount.changeset(%{
             stripe_customer_id: checkout.customer_id || billing_account.stripe_customer_id
           })
           |> Repo.update() do
      {:ok,
       %{
         ok: true,
         checkout_url: checkout.url,
         billing_account: Billing.account_payload(updated_account)
       }}
    else
      false -> {:error, {:bad_request, "Amount must be a positive integer"}}
      {:error, _reason} = error -> error
    end
  end

  def pause_sprite(nil, _slug), do: {:error, {:unauthorized, "Sign in before pausing a sprite"}}

  def pause_sprite(%HumanUser{} = human, slug) when is_binary(slug) do
    with :ok <- require_agent_formation_enabled(),
         %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, updated} <-
           RuntimeControl.pause(agent,
             runtime_status: "paused",
             actor_type: "human_user",
             human_user_id: human.id,
             source: "formation_api_pause"
           ) do
      {:ok, %{ok: true, sprite: sprite_runtime_control_payload(updated)}}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, {:unavailable, _message}} = error -> error
      {:error, reason} -> runtime_control_error(reason, "pause")
    end
  end

  def resume_sprite(nil, _slug), do: {:error, {:unauthorized, "Sign in before resuming a sprite"}}

  def resume_sprite(%HumanUser{} = human, slug) when is_binary(slug) do
    with :ok <- require_agent_formation_enabled(),
         %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, billing_account} <- require_active_or_funded_billing_account(human, agent),
         {:ok, updated} <-
           RuntimeControl.resume(agent,
             actor_type: "human_user",
             human_user_id: human.id,
             source: "formation_api_resume"
           ) do
      {:ok,
       %{
         ok: true,
         sprite: sprite_runtime_control_payload(updated),
         billing_account: Billing.account_payload(billing_account, [updated])
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, {:payment_required, _message}} = error -> error
      {:error, {:unavailable, _message}} = error -> error
      {:error, reason} -> runtime_control_error(reason, "resume")
    end
  end

  def handle_stripe_webhook(raw_body, headers) when is_binary(raw_body) and is_map(headers) do
    with {:ok, event} <- StripeBilling.parse_webhook_event(raw_body, headers),
         {:ok, _result} <- persist_stripe_event_and_enqueue(event) do
      {:ok, %{ok: true}}
    end
  end

  defp persist_stripe_event_and_enqueue(event) do
    Multi.new()
    |> Multi.insert(
      :stripe_event,
      StripeEvent.changeset(%StripeEvent{}, stripe_event_attrs(event)),
      on_conflict: :nothing,
      conflict_target: [:event_id, :event_type]
    )
    |> Multi.run(:sync_job, fn _repo, %{stripe_event: stripe_event} ->
      if stripe_event.id do
        %{"stripe_event_id" => stripe_event.id}
        |> SyncStripeBillingWorker.new()
        |> Oban.insert()
      else
        {:ok, :already_recorded}
      end
    end)
    |> Repo.transaction()
  end

  defp stripe_event_attrs(event) do
    %{
      event_id: event["event_id"],
      event_type: event["event_type"],
      customer_id: event["customer_id"],
      subscription_id: event["subscription_id"],
      subscription_status: event["subscription_status"],
      mode: event["mode"],
      metadata: event["metadata"] || %{},
      processing_status: "queued"
    }
  end

  defp create_company_records(
         %HumanUser{} = human,
         %BillingAccount{} = billing_account,
         %Mint{} = mint,
         template
       ) do
    now = PlatformPhx.Clock.now()
    slug = mint.label

    attrs = %{
      owner_human_id: human.id,
      template_key: template.key,
      name: "#{titleize_slug(slug)} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: mint.fqdn,
      ens_fqdn: nil,
      status: "forming",
      public_summary: template.summary,
      hero_statement: template.hero_statement,
      sprite_name: "#{slug}-sprite",
      sprite_service_name: template.runtime_defaults[:sprite_service_name] || "hermes-workspace",
      workspace_http_port: template.runtime_defaults[:workspace_http_port] || 3000,
      hermes_adapter_type: template.runtime_defaults[:hermes_adapter_type] || "stock",
      hermes_model: template.runtime_defaults[:hermes_model] || "glm-5.1",
      hermes_persist_session: template.runtime_defaults[:hermes_persist_session] != false,
      hermes_toolsets: template.runtime_defaults[:hermes_toolsets] || [],
      hermes_runtime_plugins: template.runtime_defaults[:hermes_runtime_plugins] || [],
      hermes_shared_skills: template.runtime_defaults[:hermes_shared_skills] || [],
      runtime_status: "queued",
      checkpoint_status: "pending",
      stripe_llm_billing_status: billing_account.billing_status,
      stripe_customer_id: billing_account.stripe_customer_id,
      stripe_pricing_plan_subscription_id: billing_account.stripe_pricing_plan_subscription_id,
      sprite_free_until: DateTime.add(now, 86_400, :second),
      sprite_metering_status: "trialing",
      wallet_address: human.wallet_address,
      desired_runtime_state: "active",
      observed_runtime_state: "unknown"
    }

    Multi.new()
    |> Multi.insert(:company, Company.changeset(%Company{}, company_attrs(attrs)))
    |> Multi.insert(:agent, fn %{company: company} ->
      Agent.changeset(%Agent{}, Map.put(attrs, :company_id, company.id))
    end)
    |> Multi.insert(:subdomain, fn %{agent: agent} ->
      Subdomain.changeset(%Subdomain{}, %{
        agent_id: agent.id,
        slug: slug,
        hostname: "#{slug}.regents.sh",
        basename_fqdn: mint.fqdn,
        ens_fqdn: mint.ens_fqdn || "#{slug}.regent.eth",
        active: false
      })
    end)
    |> Multi.run(:mint_count, fn _repo, _changes -> mark_mint_formation_used(mint) end)
    |> Multi.run(:services, fn _repo, %{agent: agent} ->
      with :ok <- insert_default_services(agent, template), do: {:ok, :inserted}
    end)
    |> Multi.run(:connections, fn _repo, %{agent: agent} ->
      with :ok <- insert_default_connections(agent, template), do: {:ok, :inserted}
    end)
    |> Multi.run(:xmtp_room, fn _repo, %{agent: agent} ->
      XMTPRooms.ensure_company_room(agent)
    end)
    |> Multi.insert(:formation, fn %{agent: agent} ->
      FormationRun.changeset(%FormationRun{}, %{
        agent_id: agent.id,
        human_user_id: human.id,
        claimed_label: slug,
        status: "queued",
        current_step: "reserve_claim",
        bootstrap_script_version: @bootstrap_script_version
      })
    end)
    |> Multi.run(:event, fn _repo, %{formation: formation} ->
      event =
        FormationProgress.insert_event!(
          formation,
          "reserve_claim",
          "succeeded",
          "Your company name is saved."
        )

      {:ok, event}
    end)
    |> Multi.run(:job, fn _repo, %{agent: agent} -> enqueue_formation(agent.id) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{agent: agent, formation: formation, event: event}} ->
        FormationProgress.broadcast(formation, event)

        {:ok,
         %{
           agent:
             Repo.preload(agent, [:subdomain, :services, :connections, :artifacts, :formation_run]),
           formation: formation
         }}

      {:error, _step, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, {:bad_request, AgentPlatform.format_changeset(changeset)}}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp company_attrs(attrs) do
    %{
      owner_human_id: attrs.owner_human_id,
      name: attrs.name,
      slug: attrs.slug,
      claimed_label: attrs.claimed_label,
      status: attrs.status,
      public_summary: attrs.public_summary,
      hero_statement: attrs.hero_statement,
      metadata: %{}
    }
  end

  defp require_agent_formation_enabled do
    if RuntimeConfig.agent_formation_enabled?() do
      :ok
    else
      {:error, {:unavailable, "Hosted company opening is not available right now."}}
    end
  end

  defp access_eligibility_payload(holdings, wallet_connected?, claimed_names, available_claims) do
    approved_collection_nft? = AgentPlatform.eligible_holdings?(holdings)
    claimed_name_ready? = claimed_names != []

    %{
      eligible: wallet_connected? and approved_collection_nft? and claimed_name_ready?,
      rule: "hold_approved_collection_nft_and_claim_name",
      wallet_connected: wallet_connected?,
      approved_collection_nft: approved_collection_nft?,
      claimed_name_ready: claimed_name_ready?,
      qualifying_nft_count: qualifying_nft_count(holdings),
      available_claim_count: length(available_claims),
      approved_collections: @approved_collection_keys
    }
  end

  defp formation_state_payload(readiness, companies, active_formations, blockers) do
    active_formation = Enum.find(active_formations, &formation_active?/1)

    state =
      cond do
        companies_ready?(companies) and blockers == [] ->
          "ready"

        not is_nil(active_formation) or Enum.any?(companies, &(&1.status == "forming")) ->
          "provisioning"

        blockers != [] ->
          "blocked"

        readiness.ready ->
          "pending"

        true ->
          "pending"
      end

    %{
      state: state,
      ready: state == "ready",
      blocked: state == "blocked",
      active_formation_id: active_formation && map_value(active_formation, :id),
      current_step: active_formation && map_value(active_formation, :current_step),
      blockers: blockers
    }
  end

  defp doctor_from_formation(payload) do
    blockers = Map.get(payload, :blockers, [])
    state = Map.fetch!(payload, :formation_state)
    readiness = Map.fetch!(payload, :readiness)
    readiness_steps = Map.get(readiness, :steps, [])

    blocker_checks =
      blockers
      |> Enum.reject(fn blocker ->
        Enum.any?(readiness_steps, &(map_value(&1, :key) == map_value(blocker, :key)))
      end)
      |> Enum.map(&doctor_check_from_blocker/1)

    status = doctor_status(state)

    %{
      status: status,
      summary: doctor_summary(status, blockers),
      checks: readiness_steps ++ blocker_checks,
      blockers: blockers
    }
  end

  defp doctor_status(formation_state) do
    cond do
      map_value(formation_state, :ready) == true -> "ready"
      map_value(formation_state, :state) == "provisioning" -> "provisioning"
      true -> "blocked"
    end
  end

  defp doctor_summary("ready", _blockers), do: "Company opening is ready."
  defp doctor_summary("provisioning", _blockers), do: "Company opening is in progress."

  defp doctor_summary("blocked", [first | _rest]) do
    "Blocked: #{map_value(first, :message)}"
  end

  defp doctor_summary("blocked", _blockers), do: "Company opening is blocked."

  defp doctor_check_from_blocker(blocker) do
    key = map_value(blocker, :key)

    %{
      key: key,
      label: doctor_label(key),
      status: "needs_action",
      message: map_value(blocker, :message),
      action_label: map_value(blocker, :action_label),
      action_path: map_value(blocker, :action_path)
    }
  end

  defp doctor_label("failed_provisioning"), do: "Company opening"
  defp doctor_label("missing_subdomain"), do: "Company address"
  defp doctor_label("missing_runtime_status"), do: "Runtime status"
  defp doctor_label("failed_runtime"), do: "Hosted runtime"
  defp doctor_label("missing_hosted_service"), do: "Hosted service"
  defp doctor_label("zero_balance"), do: "Runtime credit"

  defp doctor_label(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp doctor_label(_key), do: "Formation"

  defp billing_state_payload(billing_account, companies) do
    prepaid_balance = Map.get(billing_account, :runtime_credit_balance_usd_cents, 0) || 0
    free_day_ends_at = next_free_day_ends_at(companies)
    account_allows_runtime? = billing_account_allows_runtime?(billing_account)
    runtime_allowed? = account_allows_runtime? or not is_nil(free_day_ends_at)

    state =
      cond do
        Map.get(billing_account, :status) == "past_due" ->
          "failed"

        Map.get(billing_account, :status) == "paused" ->
          "paused"

        not is_nil(free_day_ends_at) ->
          "free_day"

        account_allows_runtime? ->
          "prepaid"

        companies != [] ->
          "zero"

        true ->
          "trial"
      end

    %{
      state: state,
      account_status: Map.get(billing_account, :status, "not_connected"),
      connected: Map.get(billing_account, :connected) == true,
      prepaid_balance_usd_cents: prepaid_balance,
      free_day_ends_at: AgentPlatform.iso(free_day_ends_at),
      runtime_allowed: runtime_allowed?
    }
  end

  defp runtime_cost_state_payload(billing_account, companies) do
    free_day_ends_at = next_free_day_ends_at(companies)
    prepaid_balance = Map.get(billing_account, :runtime_credit_balance_usd_cents, 0) || 0
    runtime_allowed? = runtime_allowed?(billing_account, companies)
    paused_at_zero? = companies != [] and is_nil(free_day_ends_at) and not runtime_allowed?
    observability = Billing.runtime_cost_observability(billing_account, companies)

    phase =
      cond do
        not is_nil(free_day_ends_at) -> "free_day"
        runtime_allowed? -> "prepaid"
        paused_at_zero? -> "paused_at_zero"
        true -> "unavailable"
      end

    %{
      phase: phase,
      hourly_cost_usd_cents: @runtime_hourly_cost_usd_cents,
      free_day_ends_at: AgentPlatform.iso(free_day_ends_at),
      prepaid_balance_usd_cents: prepaid_balance,
      prepaid_drawdown_state: observability.prepaid_drawdown_state,
      last_usage_sync_at: observability.last_usage_sync_at,
      next_pause_threshold_usd_cents: observability.next_pause_threshold_usd_cents,
      pause_targets: observability.pause_targets,
      runtime_allowed: runtime_allowed?,
      paused_at_zero: paused_at_zero?,
      next_pause_reason: if(paused_at_zero?, do: "zero_balance", else: nil)
    }
  end

  defp formation_blockers(readiness, companies, billing_account) do
    readiness_blocker =
      case readiness.blocked_step do
        nil ->
          []

        blocked_step ->
          [
            %{
              key: to_string(blocked_step.key),
              message: blocked_step.message,
              action_label: blocked_step.action_label,
              action_path: blocked_step.action_path
            }
          ]
      end

    runtime_blockers =
      if Enum.any?(companies, &formation_in_progress?/1) do
        []
      else
        companies
        |> Enum.flat_map(&company_blockers(&1, billing_account))
      end

    (readiness_blocker ++ runtime_blockers)
    |> Enum.uniq_by(& &1.key)
  end

  defp company_blockers(%Agent{} = agent, billing_account) do
    []
    |> maybe_add_blocker(formation_failed?(agent), %{
      key: "failed_provisioning",
      message: "Company opening needs attention.",
      action_label: "View progress",
      action_path: provisioning_path(agent)
    })
    |> maybe_add_blocker(missing_subdomain?(agent), %{
      key: "missing_subdomain",
      message: "The company address is not active yet.",
      action_label: "View company",
      action_path: "/app/agents/#{agent.slug}"
    })
    |> maybe_add_blocker(is_nil(agent.runtime_status), %{
      key: "missing_runtime_status",
      message: "Runtime status is not available yet.",
      action_label: "View company",
      action_path: "/app/agents/#{agent.slug}"
    })
    |> maybe_add_blocker(agent.runtime_status == "failed", %{
      key: "failed_runtime",
      message: "The hosted runtime needs attention.",
      action_label: "View company",
      action_path: "/app/agents/#{agent.slug}"
    })
    |> maybe_add_blocker(is_nil(agent.sprite_name) or is_nil(agent.sprite_service_name), %{
      key: "missing_hosted_service",
      message: "The hosted service is not connected yet.",
      action_label: "View company",
      action_path: "/app/agents/#{agent.slug}"
    })
    |> maybe_add_blocker(
      Billing.effective_metering_status(agent, billing_account) == "paused",
      %{
        key: "zero_balance",
        message: "Runtime credit has reached zero.",
        action_label: "Add credit",
        action_path: "/app/billing"
      }
    )
    |> Enum.reverse()
  end

  defp company_blockers(_agent, _billing_account), do: []

  defp maybe_add_blocker(blockers, true, blocker), do: [blocker | blockers]
  defp maybe_add_blocker(blockers, false, _blocker), do: blockers

  defp qualifying_nft_count(holdings) when is_map(holdings) do
    Enum.reduce(@approved_collection_keys, 0, fn key, total ->
      total + (holdings |> Map.get(key, []) |> List.wrap() |> length())
    end)
  end

  defp qualifying_nft_count(_holdings), do: 0

  defp companies_ready?(companies) do
    Enum.any?(companies, fn
      %Agent{} = agent ->
        agent.status == "published" and agent.runtime_status in ["ready", "paused"]

      _other ->
        false
    end)
  end

  defp formation_active?(formation) do
    map_value(formation, :status) in ["queued", "running"]
  end

  defp formation_in_progress?(%Agent{status: "forming"}), do: true

  defp formation_in_progress?(%Agent{formation_run: %FormationRun{} = formation}) do
    formation.status in ["queued", "running"]
  end

  defp formation_in_progress?(_agent), do: false

  defp formation_failed?(%Agent{formation_run: %FormationRun{} = formation}),
    do: formation.status == "failed"

  defp formation_failed?(_agent), do: false

  defp provisioning_path(%Agent{formation_run: %FormationRun{id: id}}) when is_integer(id),
    do: "/app/provisioning/#{id}"

  defp provisioning_path(_agent), do: "/app/formation"

  defp missing_subdomain?(%Agent{subdomain: %Subdomain{active: true}}), do: false
  defp missing_subdomain?(%Agent{subdomain: %Subdomain{}}), do: true
  defp missing_subdomain?(%Agent{subdomain: %Ecto.Association.NotLoaded{}}), do: false
  defp missing_subdomain?(%Agent{}), do: true

  defp next_free_day_ends_at(companies) do
    now = PlatformPhx.Clock.utc_now()

    companies
    |> Enum.map(& &1.sprite_free_until)
    |> Enum.filter(&(is_struct(&1, DateTime) and DateTime.compare(&1, now) == :gt))
    |> Enum.sort(DateTime)
    |> List.first()
  end

  defp runtime_allowed?(billing_account, companies) do
    companies != [] and
      ((Map.get(billing_account, :runtime_credit_balance_usd_cents, 0) || 0) > 0 or
         not is_nil(next_free_day_ends_at(companies)))
  end

  defp billing_account_allows_runtime?(billing_account) do
    (Map.get(billing_account, :runtime_credit_balance_usd_cents, 0) || 0) > 0
  end

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp map_value(_map, _key), do: nil

  defp enqueue_formation(agent_id) do
    case %{"agent_id" => agent_id}
         |> RunFormationWorker.new()
         |> oban_module().insert() do
      {:ok, %Oban.Job{conflict?: true}} ->
        {:error, {:conflict, "The launch job is already queued for this company"}}

      {:ok, job} ->
        {:ok, job}

      {:error, %Oban.Job{}} ->
        {:error, {:conflict, "The launch job is already queued for this company"}}

      {:error, _reason} ->
        {:error, {:unavailable, "The launch queue is unavailable right now"}}
    end
  end

  defp ensure_wallet_connected(%HumanUser{} = human) do
    if AgentPlatform.linked_wallet_addresses(human) == [] do
      {:error, {:bad_request, "Connect a wallet before starting Agent Formation"}}
    else
      :ok
    end
  end

  defp ensure_eligible_holdings(holdings) do
    if AgentPlatform.eligible_holdings?(holdings) do
      :ok
    else
      {:error,
       {:forbidden, "You need Animata I, Regent Animata II, or Regents Club to create a company"}}
    end
  end

  defp require_active_billing_account(%HumanUser{} = human) do
    case Billing.ensure_account(human) do
      {:ok, %BillingAccount{billing_status: "active"} = billing_account} ->
        {:ok, billing_account}

      {:ok, _billing_account} ->
        {:error, {:payment_required, "Finish billing setup before starting a company"}}

      {:error, _reason} = error ->
        error
    end
  end

  defp require_active_or_funded_billing_account(%HumanUser{} = human, %Agent{} = agent) do
    case Billing.ensure_account(human) do
      {:ok, %BillingAccount{} = billing_account} ->
        if Billing.allows_runtime?(billing_account) or
             (is_struct(agent.sprite_free_until, DateTime) and
                DateTime.compare(agent.sprite_free_until, PlatformPhx.Clock.utc_now()) == :gt) do
          {:ok, billing_account}
        else
          {:error, {:payment_required, "Add runtime credit before resuming this company"}}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp require_customer_template do
    case AgentPlatform.get_template(@default_template_key) do
      nil -> {:error, {:unavailable, "Customer start template is missing"}}
      template -> {:ok, template}
    end
  end

  defp runtime_control_error({:unauthorized, _message} = reason, _action), do: {:error, reason}
  defp runtime_control_error({:not_found, _message} = reason, _action), do: {:error, reason}

  defp runtime_control_error(reason, action) do
    Logger.warning("company runtime #{action} failed #{inspect(%{reason: reason})}")

    {:error, {:external, :sprite, PublicErrors.company_runtime()}}
  end

  defp require_available_claimed_name(%HumanUser{} = human, attrs) do
    claimed_label =
      attrs
      |> Map.get("claimedLabel")
      |> AgentPlatform.normalize_slug()

    wallets = AgentPlatform.linked_wallet_addresses(human)

    cond do
      claimed_label == nil ->
        {:error, {:bad_request, "Claim a name before starting Agent Formation"}}

      wallets == [] ->
        {:error, {:bad_request, "Connect a wallet before starting Agent Formation"}}

      true ->
        case Repo.one(
               from(mint in Mint,
                 where: mint.label == ^claimed_label and mint.owner_address in ^wallets,
                 limit: 1
               )
             ) do
          %Mint{formation_agent_slug: formation_agent_slug}
          when is_binary(formation_agent_slug) ->
            {:error, {:conflict, "That claimed name is already active as a company"}}

          %Mint{} = mint ->
            {:ok, mint}

          nil ->
            {:error, {:forbidden, "That claimed name is not available in your account"}}
        end
    end
  end

  defp slug_taken?(slug) when is_binary(slug) do
    Repo.exists?(from(agent in Agent, where: agent.slug == ^AgentPlatform.normalize_slug(slug)))
  end

  defp slug_taken?(_slug), do: false

  defp mark_mint_formation_used(%Mint{} = mint) do
    count =
      from(
        row in Mint,
        where: row.id == ^mint.id and is_nil(row.formation_agent_slug)
      )
      |> Repo.update_all(set: [formation_agent_slug: mint.label, is_in_use: true])
      |> elem(0)

    if count == 1 do
      {:ok, count}
    else
      {:error, {:conflict, "That claimed name is already active as a company"}}
    end
  end

  defp insert_default_services(%Agent{} = agent, template) do
    Enum.reduce_while(template.services, :ok, fn service, _acc ->
      attrs = %{
        agent_id: agent.id,
        slug: service.slug,
        name: service.name,
        summary: service.summary,
        price_label: service.price_label,
        payment_rail: service.payment_rail,
        delivery_mode: "async",
        public_result_default: service.public_result_default,
        sort_order: service.sort_order
      }

      case %Service{} |> Service.changeset(attrs) |> Repo.insert() do
        {:ok, _inserted} ->
          {:cont, :ok}

        {:error, changeset} ->
          {:halt, {:error, {:bad_request, AgentPlatform.format_changeset(changeset)}}}
      end
    end)
  end

  defp insert_default_connections(%Agent{} = agent, template) do
    Enum.reduce_while(template.connection_defaults, :ok, fn connection, _acc ->
      attrs = %{
        agent_id: agent.id,
        kind: connection.kind,
        status: connection.status,
        display_name: connection.display_name,
        external_ref: "#{agent.slug}-#{connection.kind}",
        details: %{},
        connected_at:
          if(connection.status == "connected",
            do: PlatformPhx.Clock.now(),
            else: nil
          )
      }

      case %Connection{} |> Connection.changeset(attrs) |> Repo.insert() do
        {:ok, _inserted} ->
          {:cont, :ok}

        {:error, changeset} ->
          {:halt, {:error, {:bad_request, AgentPlatform.format_changeset(changeset)}}}
      end
    end)
  end

  defp template_ready? do
    not is_nil(AgentPlatform.get_template(@default_template_key))
  end

  defp serialize_formation(nil), do: nil

  defp serialize_formation(%FormationRun{} = formation) do
    events =
      formation
      |> maybe_preload_events()
      |> Map.get(:events, [])
      |> Enum.sort_by(&event_sort_key/1, :asc)
      |> Enum.map(&serialize_formation_event/1)

    %{
      id: formation.id,
      claimed_label: formation.claimed_label,
      status: formation.status,
      current_step: formation.current_step,
      attempt_count: formation.attempt_count,
      last_error_step: formation.last_error_step,
      last_error_message: formation.last_error_message,
      started_at: AgentPlatform.iso(formation.started_at),
      last_heartbeat_at: AgentPlatform.iso(formation.last_heartbeat_at),
      completed_at: AgentPlatform.iso(formation.completed_at),
      events: events
    }
  end

  defp formation_claim_used?(claim) when is_map(claim) do
    claim.in_use == true
  end

  defp maybe_preload_events(%FormationRun{events: events} = formation) when is_list(events),
    do: formation

  defp maybe_preload_events(%FormationRun{} = formation), do: Repo.preload(formation, :events)

  defp serialize_formation_event(event) do
    %{
      step: event.step,
      status: event.status,
      message: event.message,
      created_at: AgentPlatform.iso(event.created_at)
    }
  end

  defp event_sort_key(%{created_at: %DateTime{} = created_at}),
    do: DateTime.to_unix(created_at, :microsecond)

  defp event_sort_key(_event), do: 0

  defp empty_holdings do
    %{
      "animata1" => [],
      "animata2" => [],
      "animataPass" => []
    }
  end

  defp normalize_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _other -> false
    end
  end

  defp normalize_positive_integer(_value), do: false

  defp oban_module do
    :platform_phx
    |> Application.get_env(:formation, [])
    |> Keyword.get(:oban_module, Oban)
  end

  defp build_billing_setup_checkout_urls(attrs) do
    claimed_label =
      attrs
      |> Map.get("claimedLabel")
      |> AgentPlatform.normalize_slug()

    success_path =
      "/app/formation?" <>
        URI.encode_query(
          %{"billing" => "success"}
          |> maybe_put_claimed_label(claimed_label)
        )

    cancel_path =
      "/app/billing?" <>
        URI.encode_query(
          %{"billing" => "cancel"}
          |> maybe_put_claimed_label(claimed_label)
        )

    {:ok,
     %{
       success_url: Endpoint.url() <> success_path,
       cancel_url: Endpoint.url() <> cancel_path
     }}
  end

  defp maybe_put_claimed_label(params, nil), do: params

  defp maybe_put_claimed_label(params, claimed_label),
    do: Map.put(params, "claimedLabel", claimed_label)

  defp sprite_runtime_control_payload(%Agent{} = agent) do
    %{
      slug: agent.slug,
      desired_runtime_state: agent.desired_runtime_state,
      observed_runtime_state: agent.observed_runtime_state,
      runtime_status: Billing.effective_runtime_status(agent)
    }
  end

  defp titleize_slug(slug) do
    slug
    |> String.split("-")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
