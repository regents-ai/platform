defmodule PlatformPhx.AgentPlatform.Ens do
  @moduledoc false

  import Ecto.Query, warn: false

  alias AgentEns
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.Ethereum
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig

  @ethereum_chain_id 1
  @base_chain_id 8453

  def prepare_upgrade(nil, _claim_id),
    do: {:error, {:unauthorized, "Sign in before upgrading a Regent name"}}

  def prepare_upgrade(%HumanUser{} = human, claim_id) do
    with {:ok, claim} <- owned_claim(human, claim_id),
         :ok <- ensure_claim_reserved_or_retryable(claim),
         {:ok, prepared} <- regent_upgrade_tx(claim),
         {:ok, updated_claim} <- set_claim_status(claim, %{claim_status: "upgrade_pending"}) do
      {:ok,
       %{
         ok: true,
         claim: serialize_claim(updated_claim),
         prepared: prepared
       }}
    end
  end

  def confirm_upgrade(nil, _claim_id, _attrs),
    do: {:error, {:unauthorized, "Sign in before confirming a Regent name upgrade"}}

  def confirm_upgrade(%HumanUser{} = human, claim_id, attrs) when is_map(attrs) do
    with {:ok, claim} <- owned_claim(human, claim_id),
         {:ok, tx_hash} <- required_tx_hash(attrs["tx_hash"]),
         :ok <- verify_upgrade_receipt(tx_hash),
         {:ok, updated_claim} <-
           set_claim_status(claim, %{
             claim_status: "onchain_live",
             upgrade_tx_hash: tx_hash,
             upgraded_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }) do
      {:ok, %{ok: true, claim: serialize_claim(updated_claim)}}
    else
      {:error, {:external, _source, _message}} ->
        with {:ok, claim} <- owned_claim(human, claim_id),
             {:ok, failed_claim} <- set_claim_status(claim, %{claim_status: "upgrade_failed"}) do
          {:ok, %{ok: true, claim: serialize_claim(failed_claim)}}
        end

      {:error, _reason} = error ->
        error
    end
  end

  def attach(nil, _slug, _attrs),
    do: {:error, {:unauthorized, "Sign in before attaching a Regent name"}}

  def attach(%HumanUser{} = human, slug, attrs) when is_binary(slug) and is_map(attrs) do
    with %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         :ok <- ensure_agent_completed(agent),
         :ok <- ensure_agent_not_attached(agent),
         {:ok, claim} <- owned_claim(human, attrs["claim_id"]),
         :ok <- ensure_claim_live(claim),
         :ok <- ensure_claim_not_attached(claim),
         {:ok, _result} <- attach_claim_transaction(agent, claim),
         reloaded <- AgentPlatform.get_owned_agent(human, slug),
         updated_claim <- Repo.get!(Mint, claim.id) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(reloaded, :private),
         claim: serialize_claim(updated_claim)
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def detach(nil, _slug), do: {:error, {:unauthorized, "Sign in before detaching a Regent name"}}

  def detach(%HumanUser{} = human, slug) when is_binary(slug) do
    with %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, _result} <- detach_claim_transaction(agent),
         reloaded <- AgentPlatform.get_owned_agent(human, slug) do
      {:ok, %{ok: true, agent: AgentPlatform.serialize_agent(reloaded, :private)}}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def link_plan(nil, _slug, _attrs),
    do: {:error, {:unauthorized, "Sign in before planning an ENS link"}}

  def link_plan(%HumanUser{} = human, slug, attrs) when is_binary(slug) and is_map(attrs) do
    with %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, claim} <- attached_claim(agent),
         {:ok, input} <- build_link_input(claim, attrs),
         {:ok, plan} <- AgentEns.plan_link(input) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(agent, :private),
         link: serialize_link_plan(plan)
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def prepare_bidirectional(nil, _slug, _attrs),
    do: {:error, {:unauthorized, "Sign in before preparing an ENS link"}}

  def prepare_bidirectional(%HumanUser{} = human, slug, attrs)
      when is_binary(slug) and is_map(attrs) do
    with %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, claim} <- attached_claim(agent),
         {:ok, input} <- build_link_input(claim, attrs),
         {:ok, plan} <- AgentEns.plan_link(input) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(agent, :private),
         prepared: %{
           plan: serialize_link_plan(plan),
           ensip25: maybe_prepare_regent_ensip25(plan, claim, input),
           erc8004: maybe_prepare_erc8004(plan, input),
           reverse: maybe_prepare_reverse(input, claim.ens_fqdn)
         }
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def prepare_primary(agent_claims, attrs) when is_map(agent_claims) and is_map(attrs) do
    with {:ok, ens_name} <- required_ens_name(attrs["ens_name"]),
         {:ok, tx} <-
           AgentEns.Tx.build_reverse_set_name_tx(%{
             chain_id: @ethereum_chain_id,
             ens_name: ens_name
           }) do
      {:ok,
       %{
         ok: true,
         prepared: %{
           resource: ens_name,
           action: "set_primary_name",
           chain_id: tx.chain_id,
           ens_name: ens_name,
           tx_request: serialize_tx_request(tx),
           caller_wallet_address: agent_claims["wallet_address"]
         }
       }}
    end
  end

  def prepare_primary(_agent_claims, _attrs),
    do: {:error, {:unauthorized, "Signed agent authentication failed"}}

  defp owned_claim(%HumanUser{} = human, claim_id) do
    wallets = AgentPlatform.linked_wallet_addresses(human)

    with {:ok, claim_id} <- required_integer(claim_id, "claim_id"),
         %Mint{} = claim <-
           Repo.one(
             from mint in Mint,
               where: mint.id == ^claim_id and mint.owner_address in ^wallets,
               limit: 1
           ) do
      {:ok, claim}
    else
      nil -> {:error, {:not_found, "Claimed name not found"}}
      {:error, _reason} = error -> error
    end
  end

  defp attached_claim(%Agent{} = agent) do
    case Repo.one(
           from mint in Mint,
             where: mint.attached_agent_slug == ^agent.slug,
             limit: 1
         ) do
      %Mint{} = claim -> {:ok, claim}
      nil -> {:error, {:conflict, "Attach an onchain Regent ENS name before linking it"}}
    end
  end

  defp ensure_claim_reserved_or_retryable(%Mint{claim_status: status})
       when status in ["reserved", "upgrade_failed"],
       do: :ok

  defp ensure_claim_reserved_or_retryable(%Mint{claim_status: "onchain_live"}),
    do: {:error, {:conflict, "That Regent ENS name is already live onchain"}}

  defp ensure_claim_reserved_or_retryable(%Mint{}),
    do: {:error, {:conflict, "That Regent ENS name upgrade is already in progress"}}

  defp ensure_claim_live(%Mint{claim_status: "onchain_live"}), do: :ok

  defp ensure_claim_live(%Mint{}),
    do: {:error, {:conflict, "Only onchain Regent ENS names can be attached to a company"}}

  defp ensure_claim_not_attached(%Mint{attached_agent_slug: nil}), do: :ok

  defp ensure_claim_not_attached(%Mint{}),
    do: {:error, {:conflict, "That Regent ENS name is already attached to a company"}}

  defp ensure_agent_completed(%Agent{status: "published"}), do: :ok

  defp ensure_agent_completed(%Agent{}),
    do: {:error, {:conflict, "Finish creating the company before attaching a Regent ENS name"}}

  defp ensure_agent_not_attached(%Agent{ens_fqdn: value}) when value in [nil, ""], do: :ok

  defp ensure_agent_not_attached(%Agent{}),
    do: {:error, {:conflict, "Detach the current Regent ENS name before attaching a new one"}}

  defp regent_upgrade_tx(%Mint{} = claim) do
    with registrar when is_binary(registrar) <- RuntimeConfig.regent_ens_registrar_address(),
         owner when is_binary(owner) <- RuntimeConfig.regent_ens_owner_address(),
         {:ok, tx} <-
           AgentEns.prepare_regent_subname_upgrade(%{
             chain_id: @ethereum_chain_id,
             registrar_address: registrar,
             label: claim.label,
             owner_address: owner,
             resolver_address: RuntimeConfig.ens_public_resolver_address()
           }) do
      {:ok,
       %{
         resource: claim.ens_fqdn || "#{claim.label}.regent.eth",
         action: "upgrade_regent_subname",
         chain_id: tx.chain_id,
         expected_name: claim.ens_fqdn || "#{claim.label}.regent.eth",
         tx_request: serialize_tx_request(tx)
       }}
    else
      nil -> {:error, {:unavailable, "The Regent ENS registrar is not configured"}}
      {:error, _reason} = error -> error
    end
  end

  defp verify_upgrade_receipt(tx_hash) do
    with rpc_url when is_binary(rpc_url) <- RuntimeConfig.ethereum_rpc_url(),
         {:ok, %{"status" => status}} <-
           Ethereum.json_rpc(rpc_url, "eth_getTransactionReceipt", [tx_hash]),
         true <- status == "0x1" do
      :ok
    else
      nil ->
        {:error, {:unavailable, "Ethereum mainnet RPC is not configured"}}

      {:ok, nil} ->
        {:error, {:external, :ethereum, "That mainnet transaction is not confirmed yet"}}

      false ->
        {:error, {:external, :ethereum, "That mainnet transaction failed"}}

      {:ok, _receipt} ->
        {:error, {:external, :ethereum, "That mainnet transaction receipt is incomplete"}}

      {:error, message} when is_binary(message) ->
        {:error, {:external, :ethereum, message}}
    end
  end

  defp attach_claim_transaction(%Agent{} = agent, %Mint{} = claim) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      with {:ok, _claim} <-
             claim
             |> Mint.changeset(%{attached_agent_slug: agent.slug})
             |> Repo.update(),
           {:ok, _agent} <-
             agent
             |> Agent.changeset(%{ens_fqdn: claim.ens_fqdn, updated_at: now})
             |> Repo.update(),
           {:ok, _subdomain} <- maybe_update_subdomain(agent, claim.ens_fqdn) do
        :ok
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  defp detach_claim_transaction(%Agent{} = agent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      Repo.update_all(
        from(mint in Mint, where: mint.attached_agent_slug == ^agent.slug),
        set: [attached_agent_slug: nil]
      )

      with {:ok, _agent} <-
             agent
             |> Agent.changeset(%{ens_fqdn: nil, updated_at: now})
             |> Repo.update() do
        :ok
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  defp maybe_update_subdomain(%Agent{id: agent_id}, ens_fqdn) when is_binary(ens_fqdn) do
    case Repo.get_by(Subdomain, agent_id: agent_id) do
      nil ->
        {:ok, nil}

      %Subdomain{} = subdomain ->
        subdomain
        |> Subdomain.changeset(%{ens_fqdn: ens_fqdn})
        |> Repo.update()
    end
  end

  defp maybe_update_subdomain(_agent, _ens_fqdn), do: {:ok, nil}

  defp set_claim_status(%Mint{} = claim, attrs) do
    claim
    |> Mint.changeset(attrs)
    |> Repo.update()
  end

  defp build_link_input(%Mint{} = claim, attrs) do
    with {:ok, agent_id} <- required_agent_id(attrs["agent_id"]),
         {:ok, ens_rpc_url} <-
           required_runtime_value(RuntimeConfig.ethereum_rpc_url(), "Ethereum mainnet RPC"),
         {:ok, registry_rpc_url} <-
           required_runtime_value(RuntimeConfig.base_rpc_url(), "Base mainnet RPC"),
         {:ok, registry_address} <-
           required_runtime_value(
             attrs["registry_address"] || RuntimeConfig.base_identity_registry_address(),
             "Base identity registry"
           ) do
      {:ok,
       %{
         ens_name: claim.ens_fqdn,
         ens_chain_id: @ethereum_chain_id,
         ens_rpc_url: ens_rpc_url,
         registry_chain_id: @base_chain_id,
         registry_rpc_url: registry_rpc_url,
         registry_address: registry_address,
         agent_id: agent_id,
         signer_address: attrs["signer_address"],
         include_reverse?: truthy?(attrs["include_reverse"]),
         current_agent_uri: attrs["current_agent_uri"],
         rpc_module: attrs["rpc_module"],
         erc8004_fetcher: attrs["erc8004_fetcher"],
         erc8004_fetch_opts: attrs["erc8004_fetch_opts"]
       }}
    end
  end

  defp maybe_prepare_regent_ensip25(plan, _claim, _input) when plan.verify_status == :verified,
    do: :noop

  defp maybe_prepare_regent_ensip25(_plan, %Mint{} = claim, input) do
    case AgentEns.prepare_regent_ensip25_update(%{
           chain_id: @ethereum_chain_id,
           registrar_address: RuntimeConfig.regent_ens_registrar_address(),
           label: claim.label,
           registry_chain_id: @base_chain_id,
           registry_address: input.registry_address,
           agent_id: input.agent_id,
           value: "1"
         }) do
      {:ok, tx} ->
        %{
          resource: claim.ens_fqdn,
          action: "write_ensip25_proof",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          tx_request: serialize_tx_request(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp maybe_prepare_erc8004(plan, _input) when plan.erc8004_status == :ens_service_present,
    do: :noop

  defp maybe_prepare_erc8004(_plan, input) do
    case AgentEns.prepare_erc8004_update(input) do
      {:ok, prepared} ->
        %{
          resource: "erc8004",
          action: "update_agent_registration",
          chain_id: prepared.tx.chain_id,
          target: prepared.tx.to,
          description: prepared.tx.description,
          tx_request: serialize_tx_request(prepared.tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp maybe_prepare_reverse(%{"include_reverse" => value}, _ens_name)
       when value in [false, nil, "false", "0"],
       do: :skipped

  defp maybe_prepare_reverse(%{include_reverse: false}, _ens_name), do: :skipped

  defp maybe_prepare_reverse(_input, ens_name) do
    case AgentEns.Tx.build_reverse_set_name_tx(%{
           chain_id: @ethereum_chain_id,
           ens_name: ens_name
         }) do
      {:ok, tx} ->
        %{
          resource: ens_name,
          action: "set_primary_name",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          tx_request: serialize_tx_request(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp serialize_claim(%Mint{} = claim) do
    %{
      id: claim.id,
      label: claim.label,
      fqdn: claim.fqdn,
      ens_fqdn: claim.ens_fqdn || "#{claim.label}.regent.eth",
      claimed_at: iso(claim.created_at),
      claim_status: claim.claim_status,
      upgrade_tx_hash: claim.upgrade_tx_hash,
      upgraded_at: iso(claim.upgraded_at),
      formation_agent_slug: claim.formation_agent_slug,
      attached_agent_slug: claim.attached_agent_slug
    }
  end

  defp serialize_link_plan(plan) do
    %{
      ens_name: plan.normalized_ens_name,
      ensip25_key: plan.ensip25_key,
      ensip25_status: Atom.to_string(plan.verify_status),
      erc8004_status: Atom.to_string(plan.erc8004_status),
      reverse_status: Atom.to_string(plan.reverse_status),
      warnings: plan.warnings || []
    }
  end

  defp serialize_tx_request(tx) do
    %{
      chain_id: tx.chain_id,
      to: tx.to,
      value: Integer.to_string(tx.value || 0),
      data: tx.data
    }
  end

  defp required_integer(value, _label) when is_integer(value), do: {:ok, value}

  defp required_integer(value, label) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, {:bad_request, "#{label} must be an integer"}}
    end
  end

  defp required_integer(_value, label),
    do: {:error, {:bad_request, "#{label} must be an integer"}}

  defp required_agent_id(value) do
    case value do
      int when is_integer(int) and int >= 0 ->
        {:ok, int}

      text when is_binary(text) ->
        case String.trim(text) do
          "" -> {:error, {:bad_request, "agent_id is required to plan the ENS link"}}
          trimmed -> {:ok, trimmed}
        end

      _ ->
        {:error, {:bad_request, "agent_id is required to plan the ENS link"}}
    end
  end

  defp required_tx_hash(value) when is_binary(value) and value != "" do
    if Ethereum.valid_tx_hash?(value) do
      {:ok, String.trim(value)}
    else
      {:error, {:bad_request, "tx_hash must be a 32-byte hex transaction hash"}}
    end
  end

  defp required_tx_hash(_value),
    do: {:error, {:bad_request, "tx_hash must be a 32-byte hex transaction hash"}}

  defp required_runtime_value(value, _label) when is_binary(value) and value != "",
    do: {:ok, value}

  defp required_runtime_value(_value, label),
    do: {:error, {:unavailable, "#{label} is not configured"}}

  defp required_ens_name(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, {:bad_request, "ens_name is required"}}
      trimmed -> {:ok, trimmed}
    end
  end

  defp required_ens_name(_value), do: {:error, {:bad_request, "ens_name is required"}}

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(_value), do: nil
end
