defmodule PlatformPhx.AgentPlatform.Ens do
  @moduledoc false

  import Ecto.Query, warn: false

  alias AgentEns
  alias AgentEns.Internal.ABI
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhx.Basenames.Mint
  alias PlatformPhx.Ethereum
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeConfig
  alias PlatformPhx.WalletAction

  @ethereum_chain_id 1
  @base_chain_id 8453
  @zero_address "0x0000000000000000000000000000000000000000"
  @upgrade_confirmations 2

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
         :ok <- verify_upgrade_receipt(claim, tx_hash),
         {:ok, updated_claim} <-
           set_claim_status(claim, %{
             claim_status: "onchain_live",
             upgrade_tx_hash: tx_hash,
             upgraded_at: PlatformPhx.Clock.now()
           }) do
      {:ok, %{ok: true, claim: serialize_claim(updated_claim)}}
    else
      {:error, {:external, :ethereum, "That mainnet transaction failed"}} ->
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
         :ok <- ensure_agent_wallet_present(agent),
         :ok <- ensure_agent_not_attached(agent),
         {:ok, claim} <- owned_claim(human, attrs["claim_id"]),
         :ok <- ensure_claim_live(claim),
         :ok <- ensure_claim_not_attached(claim),
         {:ok, prepared} <- prepare_link_bundle(agent, claim, attrs),
         {:ok, _result} <- attach_claim_transaction(agent, claim),
         reloaded <- AgentPlatform.get_owned_agent(human, slug),
         :ok <- AgentPlatform.clear_public_agent_cache(reloaded),
         updated_claim <- Repo.get!(Mint, claim.id) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(reloaded, :private),
         claim: serialize_claim(updated_claim),
         prepared: prepared
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def detach(nil, _slug), do: {:error, {:unauthorized, "Sign in before detaching a Regent name"}}

  def detach(%HumanUser{} = human, slug) when is_binary(slug) do
    detach(human, slug, %{})
  end

  def detach(%HumanUser{} = human, slug, attrs) when is_binary(slug) and is_map(attrs) do
    with %Agent{} = agent <- AgentPlatform.get_owned_agent(human, slug),
         {:ok, claim} <- attached_claim(agent),
         {:ok, cleanup} <- prepare_detach_cleanup(agent, claim, attrs),
         {:ok, _result} <- detach_claim_transaction(agent, claim),
         reloaded <- AgentPlatform.get_owned_agent(human, slug),
         :ok <- AgentPlatform.clear_public_agent_cache(reloaded),
         updated_claim <- Repo.get!(Mint, claim.id) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(reloaded, :private),
         claim: serialize_claim(updated_claim),
         cleanup: cleanup
       }}
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
         {:ok, input} <- build_link_input(agent, claim, attrs),
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
         {:ok, prepared} <- prepare_link_bundle(agent, claim, attrs) do
      {:ok,
       %{
         ok: true,
         agent: AgentPlatform.serialize_agent(agent, :private),
         prepared: prepared
       }}
    else
      nil -> {:error, {:not_found, "Company not found"}}
      {:error, _reason} = error -> error
    end
  end

  def prepare_primary(agent_claims, attrs) when is_map(agent_claims) and is_map(attrs) do
    with {:ok, ens_name} <- required_ens_name(attrs["ens_name"]),
         {:ok, wallet_address} <- required_wallet_address(agent_claims["wallet_address"]),
         {:ok, token_id} <- required_integer(agent_claims["token_id"], "token_id"),
         {:ok, registry_address} <-
           required_runtime_value(agent_claims["registry_address"], "Base identity registry"),
         %Agent{} = agent <- agent_for_primary_name(wallet_address, ens_name),
         {:ok, claim} <- attached_claim(agent),
         {:ok, input} <-
           build_link_input(agent, claim, %{
             "agent_id" => token_id,
             "registry_address" => registry_address,
             "current_agent_uri" => attrs["current_agent_uri"],
             "include_reverse" => true,
             "rpc_module" => attrs["rpc_module"],
             "erc8004_fetcher" => attrs["erc8004_fetcher"],
             "erc8004_fetch_opts" => attrs["erc8004_fetch_opts"]
           }),
         {:ok, plan} <- AgentEns.plan_link(input),
         :ok <- ensure_forward_resolution_verified(plan),
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
           wallet_action: serialize_wallet_action(tx),
           caller_wallet_address: wallet_address
         }
       }}
    else
      nil ->
        {:error,
         {:conflict,
          "Attach this Regent ENS name to the authenticated agent before setting it as the primary name"}}

      {:error, _reason} = error ->
        error
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

  defp ensure_agent_wallet_present(%Agent{wallet_address: value})
       when is_binary(value) and value != "",
       do: :ok

  defp ensure_agent_wallet_present(%Agent{}),
    do:
      {:error, {:conflict, "Finish the company wallet setup before attaching a Regent ENS name"}}

  defp ensure_agent_not_attached(%Agent{} = agent) do
    case Repo.exists?(from mint in Mint, where: mint.attached_agent_slug == ^agent.slug) do
      true ->
        {:error, {:conflict, "Detach the current Regent ENS name before attaching a new one"}}

      false ->
        :ok
    end
  end

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
         wallet_action: serialize_wallet_action(tx)
       }}
    else
      nil -> {:error, {:unavailable, "The Regent ENS registrar is not configured"}}
      {:error, _reason} = error -> error
    end
  end

  defp verify_upgrade_receipt(%Mint{} = claim, tx_hash) do
    with rpc_url when is_binary(rpc_url) <- RuntimeConfig.ethereum_rpc_url(),
         {:ok, %{"status" => status} = receipt} <-
           Ethereum.json_rpc(rpc_url, "eth_getTransactionReceipt", [tx_hash]),
         true <- status == "0x1",
         :ok <- ensure_upgrade_confirmations(rpc_url, receipt),
         {:ok, transaction} <- Ethereum.json_rpc(rpc_url, "eth_getTransactionByHash", [tx_hash]),
         :ok <- ensure_expected_upgrade_transaction(claim, transaction),
         :ok <- ensure_expected_upgrade_logs(claim, receipt) do
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
    now = PlatformPhx.Clock.now()

    Repo.transaction(fn ->
      locked_agent =
        Repo.one!(from locked in Agent, where: locked.id == ^agent.id, lock: "FOR UPDATE")

      locked_claim =
        Repo.one!(from locked in Mint, where: locked.id == ^claim.id, lock: "FOR UPDATE")

      with :ok <- ensure_agent_not_attached(locked_agent),
           :ok <- ensure_claim_live(locked_claim),
           :ok <- ensure_claim_not_attached(locked_claim),
           {:ok, _claim} <-
             locked_claim
             |> Mint.changeset(%{attached_agent_slug: agent.slug})
             |> Repo.update(),
           {:ok, _agent} <-
             locked_agent
             |> Agent.changeset(%{ens_fqdn: locked_claim.ens_fqdn, updated_at: now})
             |> Repo.update(),
           {:ok, _subdomain} <- maybe_update_subdomain(locked_agent, locked_claim.ens_fqdn) do
        :ok
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  defp detach_claim_transaction(%Agent{} = agent, %Mint{} = claim) do
    now = PlatformPhx.Clock.now()

    Repo.transaction(fn ->
      locked_agent =
        Repo.one!(from locked in Agent, where: locked.id == ^agent.id, lock: "FOR UPDATE")

      locked_claim =
        Repo.one!(from locked in Mint, where: locked.id == ^claim.id, lock: "FOR UPDATE")

      with true <- locked_claim.attached_agent_slug == agent.slug,
           {:ok, _claim} <-
             locked_claim
             |> Mint.changeset(%{attached_agent_slug: nil})
             |> Repo.update(),
           {:ok, _agent} <-
             locked_agent
             |> Agent.changeset(%{ens_fqdn: nil, updated_at: now})
             |> Repo.update(),
           {:ok, _subdomain} <- maybe_update_subdomain(locked_agent, nil) do
        :ok
      else
        false -> Repo.rollback({:conflict, "That Regent ENS name is no longer attached"})
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

  defp maybe_update_subdomain(%Agent{} = agent, nil) do
    case Repo.get_by(Subdomain, agent_id: agent.id) do
      nil ->
        {:ok, nil}

      %Subdomain{} = subdomain ->
        subdomain
        |> Subdomain.changeset(%{ens_fqdn: default_subdomain_ens_fqdn(agent)})
        |> Repo.update()
    end
  end

  defp maybe_update_subdomain(_agent, _ens_fqdn), do: {:ok, nil}

  defp default_subdomain_ens_fqdn(%Agent{claimed_label: claimed_label, slug: slug}) do
    "#{claimed_label || slug}.regent.eth"
  end

  defp set_claim_status(%Mint{} = claim, attrs) do
    claim
    |> Mint.changeset(attrs)
    |> Repo.update()
  end

  defp build_link_input(%Agent{} = agent, %Mint{} = claim, attrs) do
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
         signer_address: agent.wallet_address,
         include_reverse?: truthy?(attrs["include_reverse"]),
         current_agent_uri: attrs["current_agent_uri"],
         rpc_module:
           attrs["rpc_module"] || Application.get_env(:platform_phx, :agent_ens_rpc_module),
         erc8004_fetcher: attrs["erc8004_fetcher"],
         erc8004_fetch_opts: attrs["erc8004_fetch_opts"]
       }}
    end
  end

  defp prepare_link_bundle(%Agent{} = agent, %Mint{} = claim, attrs) do
    with {:ok, input} <- build_link_input(agent, claim, attrs),
         {:ok, plan} <- AgentEns.plan_link(input) do
      {:ok,
       %{
         plan: serialize_link_plan(plan),
         forward: maybe_prepare_regent_forward(plan, claim, agent),
         ensip25: maybe_prepare_regent_ensip25(plan, claim, input),
         erc8004: maybe_prepare_erc8004(plan, input, agent.wallet_address),
         reverse: maybe_prepare_reverse(plan, agent.wallet_address, claim.ens_fqdn),
         cleanup: %{forward: :noop, ensip25: :noop, erc8004: :noop, reverse: :skipped}
       }}
    end
  end

  defp prepare_detach_cleanup(%Agent{} = agent, %Mint{} = claim, attrs) do
    with {:ok, input} <- build_link_input(agent, claim, attrs) do
      {:ok,
       %{
         forward: prepare_regent_forward_cleanup(claim),
         ensip25: prepare_regent_ensip25_cleanup(claim, input),
         erc8004: prepare_erc8004_cleanup(input, agent.wallet_address),
         reverse: prepare_reverse_cleanup(agent.wallet_address)
       }}
    end
  end

  defp maybe_prepare_regent_forward(plan, _claim, _agent) when plan.forward_resolution_verified,
    do: :noop

  defp maybe_prepare_regent_forward(_plan, %Mint{} = claim, %Agent{} = agent) do
    case AgentEns.Tx.build_regent_addr_tx(%{
           chain_id: @ethereum_chain_id,
           registrar_address: RuntimeConfig.regent_ens_registrar_address(),
           label: claim.label,
           address: agent.wallet_address
         }) do
      {:ok, tx} ->
        %{
          resource: claim.ens_fqdn,
          action: "write_forward_address",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          wallet_action: serialize_wallet_action(tx)
        }

      {:error, _} ->
        :blocked
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
          wallet_action: serialize_wallet_action(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp maybe_prepare_erc8004(plan, _input, _wallet_address)
       when plan.erc8004_status == :ens_service_present,
       do: :noop

  defp maybe_prepare_erc8004(_plan, input, wallet_address) do
    case AgentEns.prepare_erc8004_update(input) do
      {:ok, prepared} ->
        %{
          resource: "erc8004",
          action: "update_agent_registration",
          chain_id: prepared.tx.chain_id,
          target: prepared.tx.to,
          description: prepared.tx.description,
          caller_wallet_address: wallet_address,
          wallet_action: serialize_wallet_action(prepared.tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp maybe_prepare_reverse(%{reverse_resolution_verified: true}, _wallet_address, _ens_name),
    do: :noop

  defp maybe_prepare_reverse(%{reverse_status: :not_requested}, _wallet_address, _ens_name),
    do: :skipped

  defp maybe_prepare_reverse(%{reverse_status: :unsupported_network}, _wallet_address, _ens_name),
    do: :blocked

  defp maybe_prepare_reverse(%{reverse_status: :signer_required}, _wallet_address, _ens_name),
    do: :blocked

  defp maybe_prepare_reverse(_plan, wallet_address, _ens_name)
       when not is_binary(wallet_address) or wallet_address == "",
       do: :skipped

  defp maybe_prepare_reverse(_plan, wallet_address, ens_name) do
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
          caller_wallet_address: wallet_address,
          wallet_action: serialize_wallet_action(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp prepare_regent_forward_cleanup(%Mint{} = claim) do
    case AgentEns.Tx.build_regent_addr_tx(%{
           chain_id: @ethereum_chain_id,
           registrar_address: RuntimeConfig.regent_ens_registrar_address(),
           label: claim.label,
           address: @zero_address
         }) do
      {:ok, tx} ->
        %{
          resource: claim.ens_fqdn,
          action: "clear_forward_address",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          wallet_action: serialize_wallet_action(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp prepare_regent_ensip25_cleanup(%Mint{} = claim, input) do
    case AgentEns.prepare_regent_ensip25_update(%{
           chain_id: @ethereum_chain_id,
           registrar_address: RuntimeConfig.regent_ens_registrar_address(),
           label: claim.label,
           registry_chain_id: @base_chain_id,
           registry_address: input.registry_address,
           agent_id: input.agent_id,
           value: ""
         }) do
      {:ok, tx} ->
        %{
          resource: claim.ens_fqdn,
          action: "clear_ensip25_proof",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          wallet_action: serialize_wallet_action(tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp prepare_erc8004_cleanup(input, wallet_address) do
    case AgentEns.prepare_erc8004_clear(input) do
      {:ok, prepared} ->
        %{
          resource: "erc8004",
          action: "clear_agent_registration_name",
          chain_id: prepared.tx.chain_id,
          target: prepared.tx.to,
          description: prepared.tx.description,
          caller_wallet_address: wallet_address,
          wallet_action: serialize_wallet_action(prepared.tx)
        }

      {:error, _} ->
        :blocked
    end
  end

  defp prepare_reverse_cleanup(wallet_address)
       when not is_binary(wallet_address) or wallet_address == "",
       do: :blocked

  defp prepare_reverse_cleanup(wallet_address) do
    case AgentEns.Tx.build_reverse_set_name_tx(%{
           chain_id: @ethereum_chain_id,
           ens_name: ""
         }) do
      {:ok, tx} ->
        %{
          resource: "addr.reverse",
          action: "clear_primary_name",
          chain_id: tx.chain_id,
          target: tx.to,
          description: tx.description,
          caller_wallet_address: wallet_address,
          wallet_action: serialize_wallet_action(tx)
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
      ensip25_verified: plan.verify_status == :verified,
      forward_resolution_verified: plan.forward_resolution_verified,
      reverse_resolution_verified: plan.reverse_resolution_verified,
      primary_name_verified: plan.primary_name_verified,
      fully_synced: plan.fully_synced,
      actions:
        Enum.map(plan.actions, fn action ->
          %{
            kind: Atom.to_string(action.kind),
            status: Atom.to_string(action.status),
            description: action.description,
            reason: action.reason && Atom.to_string(action.reason)
          }
        end),
      warnings: plan.warnings || []
    }
  end

  defp serialize_wallet_action(tx) do
    WalletAction.from_tx(%{
      "resource" => tx.to,
      "action" => "wallet_transaction",
      "chain_id" => tx.chain_id,
      "to" => tx.to,
      "value" => Integer.to_string(tx.value || 0),
      "data" => tx.data,
      "risk_copy" => tx.description || "Review this wallet action before confirming."
    })
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

  defp required_wallet_address(value) when is_binary(value) do
    case PlatformPhx.Ethereum.normalize_address(value) do
      nil -> {:error, {:bad_request, "wallet_address must be a 20-byte hex address"}}
      normalized -> {:ok, normalized}
    end
  end

  defp required_wallet_address(_value),
    do: {:error, {:bad_request, "wallet_address must be a 20-byte hex address"}}

  defp required_runtime_value(value, _label) when is_binary(value) and value != "",
    do: {:ok, value}

  defp required_runtime_value(_value, label),
    do: {:error, {:unavailable, "#{label} is not configured"}}

  defp required_ens_name(value) when is_binary(value) do
    case AgentEns.Normalize.normalize(value) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, _} -> {:error, {:bad_request, "ens_name must be a valid ENS name"}}
    end
  end

  defp required_ens_name(_value), do: {:error, {:bad_request, "ens_name is required"}}

  defp agent_for_primary_name(wallet_address, ens_name) do
    Repo.one(
      from agent in Agent,
        where: agent.wallet_address == ^wallet_address and agent.ens_fqdn == ^ens_name,
        limit: 1
    )
  end

  defp ensure_forward_resolution_verified(%{forward_resolution_verified: true}), do: :ok

  defp ensure_forward_resolution_verified(_plan) do
    {:error,
     {:conflict,
      "The attached Regent ENS name must already point to the authenticated agent wallet before it can be set as the primary name"}}
  end

  defp ensure_upgrade_confirmations(rpc_url, %{"blockNumber" => block_number}) do
    with {:ok, latest_block} <- Ethereum.json_rpc(rpc_url, "eth_blockNumber", []),
         latest when is_binary(latest) <- latest_block,
         confirmations <-
           Ethereum.hex_to_integer(latest) - Ethereum.hex_to_integer(block_number) + 1,
         true <- confirmations >= @upgrade_confirmations do
      :ok
    else
      false ->
        {:error,
         {:external, :ethereum,
          "That mainnet transaction needs more confirmations before it can be marked live"}}

      {:error, message} when is_binary(message) ->
        {:error, {:external, :ethereum, message}}
    end
  end

  defp ensure_upgrade_confirmations(_rpc_url, _receipt),
    do: {:error, {:external, :ethereum, "That mainnet transaction receipt is incomplete"}}

  defp ensure_expected_upgrade_transaction(%Mint{} = claim, %{"to" => to, "input" => input}) do
    with registrar when is_binary(registrar) <- RuntimeConfig.regent_ens_registrar_address(),
         owner when is_binary(owner) <- RuntimeConfig.regent_ens_owner_address(),
         resolver when is_binary(resolver) <- RuntimeConfig.ens_public_resolver_address(),
         true <-
           PlatformPhx.Ethereum.normalize_address(to) ==
             PlatformPhx.Ethereum.normalize_address(registrar),
         true <-
           String.starts_with?(input || "", ABI.selector("upgradeClaim(string,address,address)")),
         {:ok, decoded} <- decode_upgrade_claim_input(input),
         true <- decoded.label == claim.label,
         true <- decoded.owner_address == PlatformPhx.Ethereum.normalize_address(owner),
         true <- decoded.resolver_address == PlatformPhx.Ethereum.normalize_address(resolver) do
      :ok
    else
      nil ->
        {:error, {:unavailable, "The Regent ENS upgrade path is not configured"}}

      false ->
        {:error,
         {:bad_request,
          "That transaction does not match the expected Regent ENS upgrade for this claimed name"}}

      {:error, _reason} = error ->
        error
    end
  end

  defp ensure_expected_upgrade_transaction(_claim, _transaction) do
    {:error, {:external, :ethereum, "That mainnet transaction could not be loaded"}}
  end

  defp ensure_expected_upgrade_logs(%Mint{} = claim, %{"logs" => logs}) when is_list(logs) do
    expected_node = String.downcase(claim.ens_node || "")

    if expected_node != "" and
         Enum.any?(logs, fn
           %{"topics" => topics} when is_list(topics) ->
             Enum.any?(topics, &(String.downcase(&1) == expected_node))

           _ ->
             false
         end) do
      :ok
    else
      {:error,
       {:bad_request,
        "That transaction did not emit the expected Regent ENS node event for this claimed name"}}
    end
  end

  defp ensure_expected_upgrade_logs(_claim, _receipt),
    do: {:error, {:external, :ethereum, "That mainnet transaction receipt is incomplete"}}

  defp decode_upgrade_claim_input("0x" <> data) when byte_size(data) >= 8 do
    payload = binary_part(data, 8, byte_size(data) - 8)

    with {:ok, label} <- decode_dynamic_string(payload, 0),
         {:ok, owner_address} <- decode_address_word(payload, 1),
         {:ok, resolver_address} <- decode_address_word(payload, 2) do
      {:ok,
       %{
         label: label,
         owner_address: owner_address,
         resolver_address: resolver_address
       }}
    else
      _ -> {:error, {:bad_request, "That transaction input could not be decoded"}}
    end
  end

  defp decode_upgrade_claim_input(_input),
    do: {:error, {:bad_request, "That transaction input could not be decoded"}}

  defp decode_dynamic_string(payload, word_index) do
    with {:ok, offset} <- decode_word_as_integer(payload, word_index),
         {:ok, length} <- decode_word_as_integer(payload, div(offset, 32)),
         start <- (offset + 32) * 2,
         size <- length * 2,
         true <- byte_size(payload) >= start + size,
         encoded <- binary_part(payload, start, size),
         {:ok, binary} <- Base.decode16(encoded, case: :mixed) do
      {:ok, binary}
    else
      _ -> {:error, :invalid}
    end
  end

  defp decode_address_word(payload, word_index) do
    with {:ok, word} <- decode_word(payload, word_index) do
      {:ok, "0x" <> String.slice(String.downcase(word), -40, 40)}
    end
  end

  defp decode_word_as_integer(payload, word_index) do
    with {:ok, word} <- decode_word(payload, word_index) do
      {:ok, String.to_integer(word, 16)}
    else
      _ -> {:error, :invalid}
    end
  end

  defp decode_word(payload, word_index) do
    start = word_index * 64

    if byte_size(payload) >= start + 64 do
      {:ok, binary_part(payload, start, 64)}
    else
      {:error, :invalid}
    end
  end

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(_value), do: nil
end
