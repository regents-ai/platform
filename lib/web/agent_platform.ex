defmodule Web.AgentPlatform do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Web.Accounts.HumanUser
  alias Web.AgentPlatform.Agent
  alias Web.AgentPlatform.Artifact
  alias Web.AgentPlatform.Connection
  alias Web.AgentPlatform.FormationRun
  alias Web.AgentPlatform.Service
  alias Web.AgentPlatform.Subdomain
  alias Web.AgentPlatform.TemplateCatalog
  alias Web.Basenames.Mint
  alias Web.OpenSea
  alias Web.Repo

  @default_sprite_owner "regents"
  @default_hermes_model "glm-5.1"

  @type error_reason ::
          {:bad_request, String.t()}
          | {:forbidden, String.t()}
          | {:not_found, String.t()}
          | {:conflict, String.t()}
          | {:unauthorized, String.t()}
          | {:payment_required, String.t()}
          | {:unavailable, String.t()}
          | {:external, atom(), String.t()}

  def list_templates, do: TemplateCatalog.list()

  def get_template(key), do: TemplateCatalog.get(key)

  def current_human_payload(nil) do
    {:ok,
     %{
       ok: true,
       authenticated: false,
       human: nil,
       claimed_names: [],
       agents: []
     }}
  end

  def current_human_payload(%HumanUser{} = human) do
    {:ok,
     %{
       ok: true,
       authenticated: true,
       human: serialize_human(human),
       claimed_names: claimed_names_for_human(human),
       agents: Enum.map(list_owned_agents(human), &serialize_agent(&1, :private))
     }}
  end

  def list_owned_agents(nil), do: []

  def list_owned_agents(%HumanUser{id: id}) do
    Agent
    |> where([agent], agent.owner_human_id == ^id)
    |> order_by([agent], desc: agent.updated_at, asc: agent.slug)
    |> preload([:subdomain, :services, :connections, :artifacts, :formation_run])
    |> Repo.all()
  end

  def list_public_agents do
    Agent
    |> where([agent], agent.status == "published")
    |> order_by([agent], asc: agent.slug)
    |> preload([:subdomain, :services, :connections, :artifacts])
    |> Repo.all()
  end

  def get_public_agent(slug) when is_binary(slug) do
    Agent
    |> where([agent], agent.slug == ^normalize_slug(slug) and agent.status == "published")
    |> preload([:subdomain, :services, :connections, :artifacts])
    |> Repo.one()
  end

  def get_public_agent(_slug), do: nil

  def get_owned_agent(%HumanUser{} = human, slug) when is_binary(slug) do
    Agent
    |> where([agent], agent.owner_human_id == ^human.id and agent.slug == ^normalize_slug(slug))
    |> preload([:subdomain, :services, :connections, :artifacts, :formation_run])
    |> Repo.one()
  end

  def get_owned_agent(_human, _slug), do: nil

  def get_agent(agent_id) when is_integer(agent_id) do
    Agent
    |> where([agent], agent.id == ^agent_id)
    |> preload([:subdomain, :services, :connections, :artifacts, :formation_run, :owner_human])
    |> Repo.one()
  end

  def get_agent(_agent_id), do: nil

  def get_agent_by_host(host) when is_binary(host) do
    host = String.downcase(String.trim(host))

    Repo.one(
      from agent in Agent,
        join: subdomain in assoc(agent, :subdomain),
        where:
          subdomain.hostname == ^host and subdomain.active == true and
            agent.status == "published",
        preload: [:subdomain, :services, :connections, :artifacts]
    )
  end

  def get_agent_by_host(_host), do: nil

  def resolve_host_payload(host) when is_binary(host) do
    case get_agent_by_host(host) do
      %Agent{} = agent -> {:ok, %{ok: true, host: host, agent: serialize_agent(agent, :public)}}
      nil -> {:error, {:not_found, "No published agent matches that host"}}
    end
  end

  def resolve_host_payload(_host), do: {:error, {:bad_request, "Invalid host"}}

  def feed_payload(slug) when is_binary(slug) do
    case get_public_agent(slug) do
      %Agent{} = agent ->
        {:ok,
         %{
           ok: true,
           agent: %{
             slug: agent.slug,
             name: agent.name
           },
           feed: Enum.map(agent.artifacts, &serialize_artifact/1)
         }}

      nil ->
        {:error, {:not_found, "Agent not found"}}
    end
  end

  def feed_payload(_slug), do: {:error, {:bad_request, "Invalid agent slug"}}

  def claimed_names_for_human(%HumanUser{} = human) do
    wallets = linked_wallet_addresses(human)

    if wallets == [] do
      []
    else
      Mint
      |> where([mint], mint.owner_address in ^wallets)
      |> order_by([mint], desc: mint.created_at, asc: mint.label)
      |> select([mint], %{
        label: mint.label,
        fqdn: mint.fqdn,
        ens_fqdn: mint.ens_fqdn,
        created_at: mint.created_at,
        is_in_use: mint.is_in_use
      })
      |> Repo.all()
      |> Enum.map(fn name ->
        %{
          label: name.label,
          fqdn: name.fqdn,
          ens_fqdn: name.ens_fqdn,
          claimed_at: iso(name.created_at),
          in_use: name.is_in_use
        }
      end)
    end
  end

  def claimed_names_for_human(_human), do: []

  def holdings_for_human(%HumanUser{} = human) do
    case current_wallet_address(human) do
      nil -> {:ok, empty_holdings()}
      wallet_address -> OpenSea.fetch_holdings(wallet_address)
    end
  end

  def holdings_for_human(_human), do: {:ok, empty_holdings()}

  def eligible_holdings?(holdings) when is_map(holdings) do
    Enum.any?(["animata1", "animata2", "animataPass"], fn key ->
      holdings
      |> Map.get(key, [])
      |> List.wrap()
      |> Enum.any?()
    end)
  end

  def eligible_holdings?(_holdings), do: false

  def linked_wallet_addresses(%HumanUser{} = human) do
    [human.wallet_address | List.wrap(human.wallet_addresses)]
    |> Enum.map(&normalize_address/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def linked_wallet_addresses(_human), do: []

  def current_wallet_address(%HumanUser{} = human) do
    human
    |> linked_wallet_addresses()
    |> List.first()
  end

  def current_wallet_address(_human), do: nil

  def serialize_agent(agent, scope \\ :private)

  def serialize_agent(%Agent{} = agent, scope) do
    subdomain = subdomain_from_agent(agent)
    formation = formation_from_agent(agent)

    base = %{
      id: agent.id,
      owner_human_id: agent.owner_human_id,
      template_key: agent.template_key,
      name: agent.name,
      slug: agent.slug,
      claimed_label: agent.claimed_label,
      basename_fqdn: agent.basename_fqdn,
      ens_fqdn: agent.ens_fqdn,
      status: agent.status,
      public_summary: agent.public_summary,
      hero_statement: agent.hero_statement,
      wallet_address: agent.wallet_address,
      published_at: iso(agent.published_at),
      subdomain:
        if(subdomain,
          do: %{hostname: subdomain.hostname, active: subdomain.active},
          else: nil
        ),
      services: Enum.map(agent.services || [], &serialize_service/1),
      connections: Enum.map(agent.connections || [], &serialize_connection/1),
      feed:
        agent.artifacts
        |> List.wrap()
        |> Enum.filter(&(&1.visibility == "public"))
        |> Enum.map(&serialize_artifact/1)
    }

    case scope do
      :public ->
        base

      _ ->
        Map.merge(base, %{
          sprite_name: agent.sprite_name,
          sprite_url: agent.sprite_url,
          sprite_service_name: agent.sprite_service_name,
          sprite_checkpoint_ref: agent.sprite_checkpoint_ref,
          sprite_created_at: iso(agent.sprite_created_at),
          paperclip_url: agent.paperclip_url,
          paperclip_deployment_mode: agent.paperclip_deployment_mode,
          paperclip_http_port: agent.paperclip_http_port,
          paperclip_company_id: agent.paperclip_company_id,
          paperclip_agent_id: agent.paperclip_agent_id,
          hermes_adapter_type: agent.hermes_adapter_type,
          hermes_model: agent.hermes_model || @default_hermes_model,
          hermes_persist_session: agent.hermes_persist_session != false,
          hermes_toolsets: agent.hermes_toolsets || [],
          hermes_runtime_plugins: agent.hermes_runtime_plugins || [],
          hermes_shared_skills: agent.hermes_shared_skills || [],
          runtime_status: effective_runtime_status(agent),
          checkpoint_status: agent.checkpoint_status,
          runtime_last_checked_at: iso(agent.runtime_last_checked_at),
          last_formation_error: agent.last_formation_error,
          stripe_llm_billing_status: agent.stripe_llm_billing_status,
          stripe_customer_id: agent.stripe_customer_id,
          stripe_pricing_plan_subscription_id: agent.stripe_pricing_plan_subscription_id,
          sprite_free_until: iso(agent.sprite_free_until),
          sprite_credit_balance_usd_cents: agent.sprite_credit_balance_usd_cents || 0,
          sprite_metering_status: effective_metering_status(agent),
          formation: serialize_formation_run(formation)
        })
    end
  end

  def serialize_agent(nil, _scope), do: nil

  def runtime_payload_map(%Agent{} = agent) do
    runtime_defaults = runtime_defaults(agent)

    %{
      sprite: runtime_sprite_payload(agent),
      paperclip: runtime_paperclip_payload(agent, runtime_defaults),
      hermes: runtime_hermes_payload(agent, runtime_defaults),
      checkpoint: runtime_checkpoint_payload(agent),
      llm_billing:
        llm_billing_payload(
          agent.stripe_llm_billing_status,
          agent.stripe_customer_id,
          agent.stripe_pricing_plan_subscription_id
        )
    }
  end

  def runtime_payload_map(_agent), do: nil

  def llm_billing_payload(status, customer_id, subscription_id) do
    resolved_status =
      case status do
        "checkout_open" -> "checkout_open"
        "active" -> "active"
        "past_due" -> "past_due"
        _ -> "not_connected"
      end

    %{
      status: resolved_status,
      connected: resolved_status == "active",
      provider: "stripe",
      customer_id: customer_id,
      subscription_id: subscription_id,
      model_default: @default_hermes_model,
      margin_bps: 0
    }
  end

  def empty_credit_summary do
    %{
      total_balance_usd_cents: 0,
      trialing_companies: 0,
      paid_companies: 0,
      paused_companies: 0,
      companies: []
    }
  end

  def effective_runtime_status(%Agent{} = agent) do
    if effective_metering_status(agent) == "paused" do
      "paused_for_credits"
    else
      agent.runtime_status
    end
  end

  def effective_metering_status(%Agent{} = agent) do
    balance = agent.sprite_credit_balance_usd_cents || 0

    cond do
      balance > 0 ->
        "paid"

      is_struct(agent.sprite_free_until, DateTime) and
          DateTime.compare(agent.sprite_free_until, DateTime.utc_now()) == :gt ->
        "trialing"

      true ->
        "paused"
    end
  end

  def normalize_slug(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/u, "-")
    |> String.replace(~r/-+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  def normalize_slug(_value), do: nil

  def iso(nil), do: nil
  def iso(%DateTime{} = value), do: DateTime.to_iso8601(value)

  def format_changeset(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end

  defp serialize_human(%HumanUser{} = human) do
    %{
      id: human.id,
      privy_user_id: human.privy_user_id,
      wallet_address: human.wallet_address,
      wallet_addresses: linked_wallet_addresses(human),
      display_name: human.display_name,
      llm_billing:
        llm_billing_payload(
          human.stripe_llm_billing_status,
          human.stripe_customer_id,
          human.stripe_pricing_plan_subscription_id
        )
    }
  end

  defp serialize_service(%Service{} = service) do
    %{
      slug: service.slug,
      name: service.name,
      summary: service.summary,
      price_label: service.price_label,
      payment_rail: service.payment_rail,
      delivery_mode: service.delivery_mode,
      public_result_default: service.public_result_default,
      sort_order: service.sort_order
    }
  end

  defp serialize_connection(%Connection{} = connection) do
    %{
      kind: connection.kind,
      status: connection.status,
      display_name: connection.display_name,
      external_ref: connection.external_ref,
      details: connection.details || %{},
      connected_at: iso(connection.connected_at)
    }
  end

  defp serialize_artifact(%Artifact{} = artifact) do
    %{
      title: artifact.title,
      summary: artifact.summary,
      url: artifact.url,
      visibility: artifact.visibility,
      published_at: iso(artifact.published_at || artifact.created_at)
    }
  end

  defp serialize_formation_run(nil), do: nil

  defp serialize_formation_run(%FormationRun{} = formation) do
    %{
      status: formation.status,
      current_step: formation.current_step,
      attempt_count: formation.attempt_count,
      last_error_step: formation.last_error_step,
      last_error_message: formation.last_error_message,
      started_at: iso(formation.started_at),
      last_heartbeat_at: iso(formation.last_heartbeat_at),
      completed_at: iso(formation.completed_at)
    }
  end

  defp runtime_defaults(%Agent{} = agent) do
    case get_template(agent.template_key) do
      nil -> %{}
      template -> Map.get(template, :runtime_defaults, %{})
    end
  end

  defp runtime_sprite_payload(%Agent{} = agent) do
    %{
      name: agent.sprite_name,
      url: agent.sprite_url,
      status: effective_runtime_status(agent),
      owner: @default_sprite_owner,
      free_until: iso(agent.sprite_free_until),
      credit_balance_usd_cents: agent.sprite_credit_balance_usd_cents || 0,
      metering_status: effective_metering_status(agent)
    }
  end

  defp runtime_paperclip_payload(%Agent{} = agent, runtime_defaults) do
    %{
      url: agent.paperclip_url,
      company_id: agent.paperclip_company_id,
      status: effective_runtime_status(agent),
      deployment_mode:
        agent.paperclip_deployment_mode || runtime_defaults[:paperclip_deployment_mode] ||
          "authenticated",
      http_port: agent.paperclip_http_port || runtime_defaults[:paperclip_http_port] || 3100
    }
  end

  defp runtime_hermes_payload(%Agent{} = agent, runtime_defaults) do
    %{
      agent_id: agent.paperclip_agent_id,
      status: effective_runtime_status(agent),
      adapter_type:
        agent.hermes_adapter_type || runtime_defaults[:hermes_adapter_type] || "hermes_local",
      model: agent.hermes_model || runtime_defaults[:hermes_model] || @default_hermes_model,
      persist_session:
        if(is_boolean(agent.hermes_persist_session),
          do: agent.hermes_persist_session,
          else: runtime_defaults[:hermes_persist_session] != false
        ),
      toolsets:
        if(agent.hermes_toolsets in [nil, []],
          do: runtime_defaults[:hermes_toolsets] || [],
          else: agent.hermes_toolsets
        ),
      runtime_plugins:
        if(agent.hermes_runtime_plugins in [nil, []],
          do: runtime_defaults[:hermes_runtime_plugins] || [],
          else: agent.hermes_runtime_plugins
        ),
      shared_skills:
        if(agent.hermes_shared_skills in [nil, []],
          do: runtime_defaults[:hermes_shared_skills] || [],
          else: agent.hermes_shared_skills
        )
    }
  end

  defp runtime_checkpoint_payload(%Agent{} = agent) do
    %{status: agent.checkpoint_status}
  end

  defp empty_holdings do
    %{
      "animata1" => [],
      "animata2" => [],
      "animataPass" => []
    }
  end

  defp formation_from_agent(%Agent{formation_run: %FormationRun{} = formation}), do: formation
  defp formation_from_agent(_agent), do: nil

  defp subdomain_from_agent(%Agent{subdomain: %Subdomain{} = subdomain}), do: subdomain
  defp subdomain_from_agent(_agent), do: nil

  defp normalize_address(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_address(_value), do: nil
end
