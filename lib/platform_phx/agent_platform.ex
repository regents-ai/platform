defmodule PlatformPhx.AgentPlatform do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.Accounts.AvatarSelection
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Agentbook
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Artifact
  alias PlatformPhx.AgentPlatform.Billing
  alias PlatformPhx.AgentPlatform.CompanyProfiles
  alias PlatformPhx.AgentPlatform.Connection
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.Profiles
  alias PlatformPhx.AgentPlatform.WorkspaceBootstrap
  alias PlatformPhx.AgentPlatform.Service
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.AgentPlatform.TemplateCatalog
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.OpenSea
  alias PlatformPhx.Repo

  @default_sprite_owner "regents"
  @default_hermes_model "glm-5.1"
  @public_cache_ttl_seconds 60

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
    billing_account = Billing.get_account(human)

    {:ok,
     %{
       ok: true,
       authenticated: true,
       human: serialize_human(human, billing_account),
       claimed_names: claimed_names_for_human(human),
       agents: serialize_agents(list_owned_agents(human), :private)
     }}
  end

  def list_owned_agents(nil), do: []

  def list_owned_agents(%HumanUser{id: id}) do
    Agent
    |> where([agent], agent.owner_human_id == ^id)
    |> order_by([agent], desc: agent.updated_at, asc: agent.slug)
    |> preload([
      :subdomain,
      :services,
      :connections,
      :artifacts,
      :owner_human,
      :company,
      formation_run: :events
    ])
    |> Repo.all()
  end

  def list_public_agents do
    CompanyProfiles.list_agents()
  end

  def get_public_agent(slug) when is_binary(slug) do
    CompanyProfiles.get_agent_by_slug(slug)
  end

  def get_public_agent(_slug), do: nil

  def get_owned_agent(%HumanUser{} = human, slug) when is_binary(slug) do
    Agent
    |> where([agent], agent.owner_human_id == ^human.id and agent.slug == ^normalize_slug(slug))
    |> preload([
      :subdomain,
      :services,
      :connections,
      :artifacts,
      :owner_human,
      :company,
      formation_run: :events
    ])
    |> Repo.one()
  end

  def get_owned_agent(_human, _slug), do: nil

  def get_agent(agent_id) when is_integer(agent_id) do
    Agent
    |> where([agent], agent.id == ^agent_id)
    |> preload([
      :subdomain,
      :services,
      :connections,
      :artifacts,
      :owner_human,
      :company,
      formation_run: :events
    ])
    |> Repo.one()
  end

  def get_agent(_agent_id), do: nil

  def get_agent_by_host(host) when is_binary(host) do
    CompanyProfiles.get_agent_by_host(host)
  end

  def get_agent_by_host(_host), do: nil

  def resolve_host_payload(host) when is_binary(host) do
    cache_key = public_cache_key(:resolve_host, normalize_host(host))

    PlatformPhx.LocalCache.fetch(cache_key, @public_cache_ttl_seconds, fn ->
      resolve_host_payload_uncached(host)
    end)
  end

  def resolve_host_payload(_host), do: {:error, {:bad_request, "Invalid host"}}

  defp resolve_host_payload_uncached(host) do
    case CompanyProfiles.by_host(host) do
      %{agent: %Agent{} = agent, host: resolved_host} ->
        {:ok, %{ok: true, host: resolved_host, agent: serialize_agent(agent, :public)}}

      nil ->
        {:error, {:not_found, "No published agent matches that host"}}
    end
  end

  def feed_payload(slug) when is_binary(slug) do
    normalized_slug = normalize_slug(slug)
    cache_key = public_cache_key(:feed, normalized_slug)

    PlatformPhx.LocalCache.fetch(cache_key, @public_cache_ttl_seconds, fn ->
      feed_payload_uncached(normalized_slug)
    end)
  end

  def feed_payload(_slug), do: {:error, {:bad_request, "Invalid agent slug"}}

  defp feed_payload_uncached(nil), do: {:error, {:bad_request, "Invalid agent slug"}}

  defp feed_payload_uncached(slug) do
    case CompanyProfiles.by_slug(slug) do
      %{agent: %Agent{} = agent} ->
        {:ok,
         %{
           ok: true,
           agent: %{
             slug: agent.slug,
             name: agent.name
           },
           feed: public_feed(agent, agent.artifacts)
         }}

      nil ->
        {:error, {:not_found, "Agent not found"}}
    end
  end

  def clear_public_agent_cache(%Agent{} = agent) do
    hostname =
      case agent.subdomain do
        %Subdomain{hostname: hostname} when is_binary(hostname) -> hostname
        _ -> nil
      end

    keys =
      [
        public_cache_key(:feed, agent.slug),
        hostname && public_cache_key(:resolve_host, hostname)
      ]
      |> Enum.reject(&is_nil/1)

    _ = PlatformPhx.LocalCache.delete(keys)
    :ok
  end

  def clear_public_agent_cache(slug) when is_binary(slug) do
    _ = PlatformPhx.LocalCache.delete(public_cache_key(:feed, normalize_slug(slug)))
    :ok
  end

  def clear_public_agent_cache(_agent), do: :ok

  def claimed_names_for_human(%HumanUser{} = human) do
    wallets = linked_wallet_addresses(human)

    if wallets == [] do
      []
    else
      Mint
      |> where([mint], mint.owner_address in ^wallets)
      |> order_by([mint], desc: mint.created_at, asc: mint.label)
      |> select([mint], %{
        id: mint.id,
        label: mint.label,
        fqdn: mint.fqdn,
        ens_fqdn: mint.ens_fqdn,
        created_at: mint.created_at,
        claim_status: mint.claim_status,
        upgrade_tx_hash: mint.upgrade_tx_hash,
        upgraded_at: mint.upgraded_at,
        is_in_use: mint.is_in_use,
        formation_agent_slug: mint.formation_agent_slug,
        attached_agent_slug: mint.attached_agent_slug
      })
      |> Repo.all()
      |> Enum.map(fn name ->
        %{
          id: name.id,
          label: name.label,
          fqdn: name.fqdn,
          ens_fqdn: name.ens_fqdn || "#{name.label}.regent.eth",
          claimed_at: iso(name.created_at),
          claim_status: name.claim_status,
          in_use: claimed_name_in_use?(name),
          upgrade_tx_hash: name.upgrade_tx_hash,
          upgraded_at: iso(name.upgraded_at),
          formation_agent_slug: name.formation_agent_slug,
          attached_agent_slug: name.attached_agent_slug
        }
      end)
    end
  end

  def claimed_names_for_human(_human), do: []

  defp claimed_name_in_use?(name) do
    name.is_in_use == true or is_binary(name.formation_agent_slug) or
      is_binary(name.attached_agent_slug)
  end

  def holdings_for_human(%HumanUser{} = human) do
    case current_wallet_address(human) do
      nil -> {:ok, empty_holdings()}
      wallet_address -> OpenSea.fetch_holdings(wallet_address)
    end
  end

  def holdings_for_human(_human), do: {:ok, empty_holdings()}

  defdelegate save_human_avatar(human, attrs), to: Profiles

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

  def serialize_agents(agents, scope \\ :private) when is_list(agents) do
    ens_claims_by_slug = ens_claims_by_slug(agents)
    Enum.map(agents, &serialize_agent(&1, scope, ens_claims_by_slug))
  end

  def serialize_agent(agent, scope \\ :private, ens_claims_by_slug \\ nil)

  def serialize_agent(%Agent{} = agent, scope, ens_claims_by_slug) do
    subdomain = subdomain_from_agent(agent)
    formation = formation_from_agent(agent)
    billing_account = billing_account_from_agent(agent)
    metering_status = Billing.effective_metering_status(agent, billing_account)

    base = %{
      id: agent.id,
      owner_human_id: agent.owner_human_id,
      template_key: agent.template_key,
      name: agent.name,
      slug: agent.slug,
      claimed_label: agent.claimed_label,
      basename_fqdn: agent.basename_fqdn,
      ens: serialize_agent_ens(agent, ens_claims_by_slug),
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
      avatar: serialize_avatar(agent_avatar(agent)),
      feed: public_feed(agent, agent.artifacts)
    }

    case scope do
      :public ->
        base

      _ ->
        Map.merge(base, %{
          sprite_name: agent.sprite_name,
          sprite_service_name: agent.sprite_service_name,
          sprite_checkpoint_ref: agent.sprite_checkpoint_ref,
          sprite_created_at: iso(agent.sprite_created_at),
          workspace_url: agent.workspace_url,
          workspace_http_port: agent.workspace_http_port,
          hermes_adapter_type: agent.hermes_adapter_type,
          hermes_model: agent.hermes_model || @default_hermes_model,
          hermes_persist_session: agent.hermes_persist_session != false,
          hermes_toolsets: agent.hermes_toolsets || [],
          hermes_runtime_plugins: agent.hermes_runtime_plugins || [],
          hermes_shared_skills: agent.hermes_shared_skills || [],
          runtime_status: Billing.effective_runtime_status(agent, billing_account),
          checkpoint_status: agent.checkpoint_status,
          runtime_last_checked_at: iso(agent.runtime_last_checked_at),
          last_formation_error: agent.last_formation_error,
          desired_runtime_state: agent.desired_runtime_state,
          observed_runtime_state: agent.observed_runtime_state,
          sprite_free_until: iso(agent.sprite_free_until),
          sprite_metering_status: metering_status,
          formation: serialize_formation_run(formation)
        })
    end
  end

  def serialize_agent(nil, _scope, _ens_claims_by_slug), do: nil

  defp serialize_agent_ens(%Agent{} = agent, ens_claims_by_slug)
       when is_map(ens_claims_by_slug) do
    agent_ens_payload(agent, Map.get(ens_claims_by_slug, agent.slug))
  end

  defp serialize_agent_ens(%Agent{} = agent, _ens_claims_by_slug) do
    attached_claim =
      Repo.one(
        from(mint in Mint,
          where: mint.attached_agent_slug == ^agent.slug,
          select: %{
            id: mint.id,
            ens_fqdn: mint.ens_fqdn,
            claim_status: mint.claim_status
          },
          limit: 1
        )
      )

    agent_ens_payload(agent, attached_claim)
  end

  defp agent_ens_payload(%Agent{} = agent, attached_claim) do
    %{
      attached: not is_nil(attached_claim),
      claim_id: attached_claim && attached_claim.id,
      name: (attached_claim && attached_claim.ens_fqdn) || blank_to_nil(agent.ens_fqdn),
      claim_status: attached_claim && attached_claim.claim_status
    }
  end

  defp ens_claims_by_slug(agents) when is_list(agents) do
    slugs =
      agents
      |> Enum.map(& &1.slug)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if slugs == [] do
      %{}
    else
      Mint
      |> where([mint], mint.attached_agent_slug in ^slugs)
      |> select([mint], %{
        attached_agent_slug: mint.attached_agent_slug,
        id: mint.id,
        ens_fqdn: mint.ens_fqdn,
        claim_status: mint.claim_status
      })
      |> Repo.all()
      |> Map.new(&{&1.attached_agent_slug, &1})
    end
  end

  def runtime_payload_map(agent, billing_account \\ nil)

  def runtime_payload_map(%Agent{} = agent, billing_account) do
    runtime_defaults = runtime_defaults(agent)
    workspace = company_workspace(agent)

    billing_account = billing_account || billing_account_from_agent(agent)

    %{
      sprite: runtime_sprite_payload(agent, billing_account),
      workspace: runtime_workspace_payload(agent, runtime_defaults, workspace),
      hermes: runtime_hermes_payload(agent, runtime_defaults, workspace),
      checkpoint: runtime_checkpoint_payload(agent)
    }
  end

  def runtime_payload_map(_agent, _billing_account), do: nil

  defp billing_account_from_agent(%Agent{owner_human_id: human_id}) when is_integer(human_id) do
    Billing.get_account_by_human_id(human_id)
  end

  defp billing_account_from_agent(_agent), do: nil

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

  def normalize_host(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end

  def normalize_host(_value), do: nil

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

  defp serialize_human(%HumanUser{} = human, billing_account) do
    %{
      id: human.id,
      privy_user_id: human.privy_user_id,
      wallet_address: human.wallet_address,
      wallet_addresses: linked_wallet_addresses(human),
      world_human_id: human.world_human_id,
      world_verified_at: iso(human.world_verified_at),
      human_backed_trust: Agentbook.human_trust_summary(human),
      display_name: human.display_name,
      avatar: serialize_avatar(human.avatar),
      billing_account: Billing.account_payload(billing_account)
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

  defp serialize_artifact(%Agent{} = agent, %Artifact{} = artifact) do
    %{
      title: artifact.title,
      summary: artifact.summary,
      url: public_artifact_url(agent, artifact.url),
      visibility: artifact.visibility,
      published_at: iso(artifact.published_at || artifact.created_at)
    }
  end

  defp public_feed(agent, artifacts) do
    artifacts
    |> List.wrap()
    |> Enum.filter(&(&1.visibility == "public"))
    |> Enum.map(&serialize_artifact(agent, &1))
  end

  defp public_cache_key(kind, value) when is_binary(value) do
    "platform:agent-platform:public:#{kind}:#{value}:v1"
  end

  defp public_cache_key(kind, _value) do
    "platform:agent-platform:public:#{kind}:invalid:v1"
  end

  defp public_artifact_url(%Agent{slug: slug}, url) when is_binary(url) do
    if Artifact.public_url?(url) do
      expected_host = "#{slug}.regents.sh"

      case URI.parse(url) do
        %URI{host: ^expected_host} ->
          "/agents/#{slug}"

        _ ->
          url
      end
    else
      nil
    end
  end

  defp public_artifact_url(_agent, _url), do: nil

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

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil

  defp runtime_defaults(%Agent{} = agent) do
    case get_template(agent.template_key) do
      nil -> %{}
      template -> Map.get(template, :runtime_defaults, %{})
    end
  end

  defp runtime_sprite_payload(%Agent{} = agent, billing_account) do
    observability = Billing.runtime_cost_observability(billing_account, [agent])

    %{
      name: agent.sprite_name,
      status: Billing.effective_runtime_status(agent),
      owner: @default_sprite_owner,
      free_until: iso(agent.sprite_free_until),
      metering_status: Billing.effective_metering_status(agent, billing_account),
      desired_runtime_state: agent.desired_runtime_state,
      observed_runtime_state: agent.observed_runtime_state,
      prepaid_balance_usd_cents:
        Map.get(billing_account || %{}, :runtime_credit_balance_usd_cents, 0) || 0,
      prepaid_drawdown_state: observability.prepaid_drawdown_state,
      last_usage_sync_at: iso(Billing.agent_last_usage_sync_at(agent)),
      next_pause_threshold_usd_cents: observability.next_pause_threshold_usd_cents,
      will_pause_at_zero: Billing.runtime_pause_target?(agent)
    }
  end

  defp runtime_workspace_payload(%Agent{} = agent, runtime_defaults, workspace) do
    base = %{
      url: agent.workspace_url,
      status: Billing.effective_runtime_status(agent),
      http_port: agent.workspace_http_port || runtime_defaults[:workspace_http_port] || 3000
    }

    maybe_put_workspace(base, workspace)
  end

  defp runtime_hermes_payload(%Agent{} = agent, runtime_defaults, workspace) do
    base = %{
      status: Billing.effective_runtime_status(agent),
      adapter_type:
        agent.hermes_adapter_type || runtime_defaults[:hermes_adapter_type] || "stock",
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

    base
    |> maybe_put_hermes_command(workspace)
    |> maybe_put_prompt_template_version(workspace)
  end

  defp runtime_checkpoint_payload(%Agent{} = agent) do
    %{status: agent.checkpoint_status}
  end

  def empty_holdings do
    %{
      "animata1" => [],
      "animata2" => [],
      "animataPass" => []
    }
  end

  defp agent_avatar(%Agent{owner_human: %HumanUser{} = owner_human}), do: owner_human.avatar
  defp agent_avatar(_agent), do: nil

  defp serialize_avatar(avatar), do: AvatarSelection.serialize(avatar)

  defp formation_from_agent(%Agent{formation_run: %FormationRun{} = formation}), do: formation
  defp formation_from_agent(_agent), do: nil

  defp company_workspace(%Agent{formation_run: %FormationRun{} = formation}) do
    metadata = formation.metadata || %{}

    %{
      workspace_path: metadata["workspace_path"] || WorkspaceBootstrap.workspace_path(),
      workspace_seed_version:
        metadata["workspace_seed_version"] || WorkspaceBootstrap.workspace_seed_version(),
      hermes_command: metadata["hermes_command"] || WorkspaceBootstrap.hermes_command(),
      prompt_template_version:
        metadata["prompt_template_version"] || WorkspaceBootstrap.prompt_template_version()
    }
  end

  defp company_workspace(_agent), do: nil

  defp maybe_put_workspace(payload, nil), do: payload

  defp maybe_put_workspace(payload, workspace) do
    Map.merge(payload, %{
      workspace_path: workspace.workspace_path,
      workspace_seed_version: workspace.workspace_seed_version
    })
  end

  defp maybe_put_hermes_command(payload, nil), do: payload

  defp maybe_put_hermes_command(payload, workspace),
    do: Map.put(payload, :command, workspace.hermes_command)

  defp maybe_put_prompt_template_version(payload, nil), do: payload

  defp maybe_put_prompt_template_version(payload, workspace) do
    Map.put(payload, :prompt_template_version, workspace.prompt_template_version)
  end

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
