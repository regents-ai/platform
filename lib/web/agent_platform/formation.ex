defmodule Web.AgentPlatform.Formation do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Web.Accounts.HumanUser
  alias Web.AgentPlatform
  alias Web.AgentPlatform.Agent
  alias Web.AgentPlatform.Connection
  alias Web.AgentPlatform.CreditLedger
  alias Web.AgentPlatform.FormationEvent
  alias Web.AgentPlatform.FormationRun
  alias Web.AgentPlatform.Service
  alias Web.AgentPlatform.StripeLlmBilling
  alias Web.AgentPlatform.Subdomain
  alias Web.AgentPlatform.Workers.RunFormationWorker
  alias Web.Basenames.Mint
  alias Web.Repo
  alias Oban

  @default_template_key "start"
  @bootstrap_script_version "agent-formation-v1"

  def formation_payload(nil) do
    {:ok,
     %{
       ok: true,
       authenticated: false,
       wallet_address: nil,
       eligible: false,
       collections: empty_holdings(),
       claimed_names: [],
       available_claims: [],
       llm_billing: AgentPlatform.llm_billing_payload("not_connected", nil, nil),
       credits: AgentPlatform.empty_credit_summary(),
       owned_companies: [],
       active_formations: []
     }}
  end

  def formation_payload(%HumanUser{} = human) do
    with {:ok, holdings} <- AgentPlatform.holdings_for_human(human) do
      claimed_names = AgentPlatform.claimed_names_for_human(human)
      companies = AgentPlatform.list_owned_agents(human)

      {:ok,
       %{
         ok: true,
         authenticated: true,
         wallet_address: AgentPlatform.current_wallet_address(human),
         eligible: AgentPlatform.eligible_holdings?(holdings),
         collections: holdings,
         claimed_names: claimed_names,
         available_claims: Enum.reject(claimed_names, & &1.in_use),
         llm_billing:
           AgentPlatform.llm_billing_payload(
             human.stripe_llm_billing_status,
             human.stripe_customer_id,
             human.stripe_pricing_plan_subscription_id
           ),
         credits: credit_summary_map(companies),
         owned_companies: Enum.map(companies, &AgentPlatform.serialize_agent(&1, :private)),
         active_formations:
           companies
           |> Enum.map(& &1.formation_run)
           |> Enum.reject(&is_nil/1)
           |> Enum.map(&serialize_formation/1)
       }}
    end
  end

  def start_llm_billing_checkout(nil),
    do: {:error, {:unauthorized, "Sign in before starting Agent Formation billing"}}

  def start_llm_billing_checkout(%HumanUser{} = human) do
    with :ok <- ensure_wallet_connected(human),
         {:ok, checkout} <- StripeLlmBilling.create_checkout_session(human),
         {:ok, updated_human} <-
           human
           |> HumanUser.changeset(%{
             stripe_llm_billing_status: "checkout_open",
             stripe_customer_id: checkout.customer_id || human.stripe_customer_id
           })
           |> Repo.update() do
      {:ok,
       %{
         ok: true,
         checkout_url: checkout.url,
         llm_billing:
           AgentPlatform.llm_billing_payload(
             updated_human.stripe_llm_billing_status,
             updated_human.stripe_customer_id,
             updated_human.stripe_pricing_plan_subscription_id
           )
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  def create_company(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before starting Agent Formation"}}

  def create_company(%HumanUser{} = human, attrs) when is_map(attrs) do
    with :ok <- ensure_wallet_connected(human),
         {:ok, holdings} <- AgentPlatform.holdings_for_human(human),
         :ok <- ensure_eligible_holdings(holdings),
         :ok <- ensure_llm_billing_active(human),
         {:ok, template} <- require_customer_template(),
         {:ok, mint} <- require_available_claimed_name(human, attrs),
         false <- slug_taken?(mint.label),
         {:ok, %{agent: agent, formation: formation}} <-
           create_company_records(human, mint, template),
         {:ok, _job} <- enqueue_formation(agent.id) do
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
        {:ok,
         %{
           ok: true,
           agent: AgentPlatform.serialize_agent(agent, :private),
           runtime: AgentPlatform.runtime_payload_map(agent),
           formation: serialize_formation(agent.formation_run)
         }}

      nil ->
        {:error, {:not_found, "Company not found"}}
    end
  end

  def credit_summary(nil),
    do: {:error, {:unauthorized, "Sign in before reading Sprite credits"}}

  def credit_summary(%HumanUser{} = human) do
    {:ok, %{ok: true, credits: credit_summary_map(AgentPlatform.list_owned_agents(human))}}
  end

  def start_credit_checkout(nil, _attrs),
    do: {:error, {:unauthorized, "Sign in before adding Sprite credits"}}

  def start_credit_checkout(%HumanUser{} = human, attrs) when is_map(attrs) do
    with slug when is_binary(slug) <- AgentPlatform.normalize_slug(Map.get(attrs, "slug")),
         amount when is_integer(amount) and amount > 0 <-
           normalize_positive_integer(Map.get(attrs, "amountUsdCents")),
         %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, _entry} <- insert_credit_purchase(agent, amount),
         {:ok, _updated} <-
           agent
           |> Agent.changeset(%{
             sprite_credit_balance_usd_cents:
               (agent.sprite_credit_balance_usd_cents || 0) + amount,
             sprite_metering_status: "paid"
           })
           |> Repo.update() do
      reloaded = AgentPlatform.get_owned_agent(human, slug)

      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(reloaded, :private),
         credits: credit_summary_map(AgentPlatform.list_owned_agents(human))
       }}
    else
      nil -> {:error, {:bad_request, "Choose a valid company slug"}}
      false -> {:error, {:bad_request, "Amount must be a positive integer"}}
      {:error, _reason} = error -> error
      _other -> {:error, {:not_found, "Company not found"}}
    end
  end

  def handle_stripe_webhook(raw_body, headers) when is_binary(raw_body) and is_map(headers) do
    with {:ok, event} <- StripeLlmBilling.parse_webhook_event(raw_body, headers),
         {:ok, _job} <-
           Web.AgentPlatform.Workers.SyncStripeBillingWorker.new(event)
           |> Oban.insert() do
      {:ok, %{ok: true}}
    end
  end

  def create_usage_event(%Agent{} = agent, attrs) when is_map(attrs) do
    %Web.AgentPlatform.LlmUsageEvent{}
    |> Web.AgentPlatform.LlmUsageEvent.changeset(
      Map.merge(attrs, %{
        agent_id: agent.id,
        human_user_id: agent.owner_human_id,
        occurred_at:
          Map.get(attrs, :occurred_at) || DateTime.utc_now() |> DateTime.truncate(:second)
      })
    )
    |> Repo.insert()
  end

  defp create_company_records(%HumanUser{} = human, %Mint{} = mint, template) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    slug = mint.label

    attrs = %{
      owner_human_id: human.id,
      template_key: template.key,
      name: "#{titleize_slug(slug)} Regent",
      slug: slug,
      claimed_label: slug,
      basename_fqdn: mint.fqdn,
      ens_fqdn: mint.ens_fqdn || "#{slug}.regent.eth",
      status: "forming",
      public_summary: template.summary,
      hero_statement: template.hero_statement,
      sprite_name: "#{slug}-sprite",
      sprite_service_name: template.runtime_defaults[:sprite_service_name] || "paperclip",
      paperclip_deployment_mode:
        template.runtime_defaults[:paperclip_deployment_mode] || "authenticated",
      paperclip_http_port: template.runtime_defaults[:paperclip_http_port] || 3100,
      hermes_adapter_type: template.runtime_defaults[:hermes_adapter_type] || "hermes_local",
      hermes_model: template.runtime_defaults[:hermes_model] || "glm-5.1",
      hermes_persist_session: template.runtime_defaults[:hermes_persist_session] != false,
      hermes_toolsets: template.runtime_defaults[:hermes_toolsets] || [],
      hermes_runtime_plugins: template.runtime_defaults[:hermes_runtime_plugins] || [],
      hermes_shared_skills: template.runtime_defaults[:hermes_shared_skills] || [],
      runtime_status: "queued",
      checkpoint_status: "pending",
      stripe_llm_billing_status: human.stripe_llm_billing_status,
      stripe_customer_id: human.stripe_customer_id,
      stripe_pricing_plan_subscription_id: human.stripe_pricing_plan_subscription_id,
      sprite_free_until: DateTime.add(now, 86_400, :second),
      sprite_credit_balance_usd_cents: 0,
      sprite_metering_status: "trialing",
      wallet_address: human.wallet_address
    }

    Repo.transaction(fn ->
      with {:ok, agent} <- %Agent{} |> Agent.changeset(attrs) |> Repo.insert(),
           {:ok, _subdomain} <-
             %Subdomain{}
             |> Subdomain.changeset(%{
               agent_id: agent.id,
               slug: slug,
               hostname: "#{slug}.regents.sh",
               basename_fqdn: mint.fqdn,
               ens_fqdn: mint.ens_fqdn || "#{slug}.regent.eth",
               active: false
             })
             |> Repo.insert(),
           {:ok, _mint_count} <- mark_mint_in_use(mint),
           :ok <- insert_default_services(agent, template),
           :ok <- insert_default_connections(agent, template),
           {:ok, formation} <-
             %FormationRun{}
             |> FormationRun.changeset(%{
               agent_id: agent.id,
               human_user_id: human.id,
               claimed_label: slug,
               status: "queued",
               current_step: "reserve_claim",
               bootstrap_script_version: @bootstrap_script_version
             })
             |> Repo.insert(),
           {:ok, _event} <-
             %FormationEvent{}
             |> FormationEvent.changeset(%{
               formation_id: formation.id,
               step: "reserve_claim",
               status: "succeeded",
               message: "Reserved the claimed name for Agent Formation."
             })
             |> Repo.insert() do
        %{
          agent:
            Repo.preload(agent, [:subdomain, :services, :connections, :artifacts, :formation_run]),
          formation: formation
        }
      else
        {:error, changeset} when is_map(changeset) ->
          Repo.rollback({:bad_request, AgentPlatform.format_changeset(changeset)})

        {:error, _reason} = error ->
          Repo.rollback(error)
      end
    end)
  end

  defp enqueue_formation(agent_id) do
    %{"agent_id" => agent_id}
    |> RunFormationWorker.new()
    |> Oban.insert()
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

  defp ensure_llm_billing_active(%HumanUser{} = human) do
    if human.stripe_llm_billing_status == "active" do
      :ok
    else
      {:error, {:payment_required, "Start Stripe billing before Agent Formation can continue"}}
    end
  end

  defp require_customer_template do
    case AgentPlatform.get_template(@default_template_key) do
      nil -> {:error, {:unavailable, "Customer start template is missing"}}
      template -> {:ok, template}
    end
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
               from mint in Mint,
                 where: mint.label == ^claimed_label and mint.owner_address in ^wallets,
                 limit: 1
             ) do
          %Mint{is_in_use: true} ->
            {:error, {:conflict, "That claimed name is already active as a company"}}

          %Mint{} = mint ->
            {:ok, mint}

          nil ->
            {:error, {:forbidden, "That claimed name is not available in your account"}}
        end
    end
  end

  defp slug_taken?(slug) when is_binary(slug) do
    Repo.exists?(from agent in Agent, where: agent.slug == ^AgentPlatform.normalize_slug(slug))
  end

  defp slug_taken?(_slug), do: false

  defp mark_mint_in_use(%Mint{} = mint) do
    count =
      from(row in Mint, where: row.id == ^mint.id and row.is_in_use == false)
      |> Repo.update_all(set: [is_in_use: true])
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
            do: DateTime.utc_now() |> DateTime.truncate(:second),
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

  defp credit_summary_map(companies) do
    summaries =
      Enum.map(companies, fn agent ->
        %{
          slug: agent.slug,
          name: agent.name,
          runtime_status: AgentPlatform.effective_runtime_status(agent),
          sprite_metering_status: AgentPlatform.effective_metering_status(agent),
          sprite_credit_balance_usd_cents: agent.sprite_credit_balance_usd_cents || 0,
          sprite_free_until: AgentPlatform.iso(agent.sprite_free_until)
        }
      end)

    %{
      total_balance_usd_cents:
        Enum.reduce(summaries, 0, fn company, acc ->
          acc + company.sprite_credit_balance_usd_cents
        end),
      trialing_companies: Enum.count(summaries, &(&1.sprite_metering_status == "trialing")),
      paid_companies: Enum.count(summaries, &(&1.sprite_metering_status == "paid")),
      paused_companies: Enum.count(summaries, &(&1.sprite_metering_status == "paused")),
      companies: summaries
    }
  end

  defp insert_credit_purchase(%Agent{} = agent, amount) do
    %CreditLedger{}
    |> CreditLedger.changeset(%{
      agent_id: agent.id,
      entry_type: "purchase",
      amount_usd_cents: amount,
      description: "Sprite runtime credits added through Agent Formation.",
      source_ref: "manual-top-up",
      effective_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  defp serialize_formation(nil), do: nil

  defp serialize_formation(%FormationRun{} = formation) do
    %{
      id: formation.id,
      status: formation.status,
      current_step: formation.current_step,
      attempt_count: formation.attempt_count,
      last_error_step: formation.last_error_step,
      last_error_message: formation.last_error_message,
      started_at: AgentPlatform.iso(formation.started_at),
      last_heartbeat_at: AgentPlatform.iso(formation.last_heartbeat_at),
      completed_at: AgentPlatform.iso(formation.completed_at)
    }
  end

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

  defp titleize_slug(slug) do
    slug
    |> String.split("-")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
