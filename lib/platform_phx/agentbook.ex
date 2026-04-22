defmodule PlatformPhx.Agentbook do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias AgentWorld.Error
  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.Agentbook.Link
  alias PlatformPhx.Agentbook.Session
  alias PlatformPhx.Repo

  @world_network "world"
  @default_source "regents-cli"
  @session_ttl_seconds 300

  @type reason ::
          {:bad_request, String.t()}
          | {:not_found, String.t()}
          | {:unauthorized, String.t()}
          | {:conflict, String.t()}
          | {:unavailable, String.t()}

  def create_session(agent_claims, attrs, base_url)
      when is_map(agent_claims) and is_map(attrs) and is_binary(base_url) do
    with {:ok, identity} <- identity_from_claims(agent_claims),
         source <- normalize_source(Map.get(attrs, "source")),
         {:ok, approval_token} <- create_approval_token() do
      case link_for_identity(identity) do
        %Link{} = link ->
          now = DateTime.utc_now()

          session_attrs = %{
            session_id: Ecto.UUID.generate(),
            wallet_address: identity.wallet_address,
            chain_id: identity.chain_id,
            registry_address: identity.registry_address,
            token_id: identity.token_id,
            network: @world_network,
            source: source,
            approval_token_hash: hash_token(approval_token),
            status: "registered",
            world_human_id: link.world_human_id,
            platform_human_user_id: link.platform_human_user_id,
            expires_at: DateTime.add(now, @session_ttl_seconds, :second)
          }

          with {:ok, session} <- persist_created_session(session_attrs) do
            {:ok,
             serialize_session(
               session,
               approval_url(base_url, session.session_id, approval_token)
             )}
          end

        nil ->
          with {:ok, created} <-
                 registration_module().create_session(%{
                   "agent_address" => identity.wallet_address,
                   "network" => @world_network
                 }),
               {:ok, normalized} <-
                 normalize_created_session(created, identity, source, approval_token),
               {:ok, session} <- persist_created_session(normalized) do
            {:ok,
             serialize_session(
               session,
               approval_url(base_url, session.session_id, approval_token)
             )}
          else
            {:error, %Error{} = error} -> {:error, {:bad_request, Exception.message(error)}}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  def get_session_for_agent(session_id, agent_claims)
      when is_binary(session_id) and is_map(agent_claims) do
    with {:ok, identity} <- identity_from_claims(agent_claims),
         %Session{} = session <- Repo.get(Session, session_id),
         true <- same_identity?(session, identity) do
      {:ok, serialize_session(session)}
    else
      nil -> {:error, {:not_found, "Trust session not found"}}
      false -> {:error, {:not_found, "Trust session not found"}}
      {:error, _} = error -> error
    end
  end

  def get_browser_session(session_id, session_token)
      when is_binary(session_id) and is_binary(session_token) do
    with %Session{} = session <- Repo.get(Session, session_id),
         true <- valid_approval_token?(session, session_token),
         :ok <- ensure_session_not_expired(session) do
      {:ok, serialize_session(session)}
    else
      nil -> {:error, {:not_found, "Trust session not found"}}
      false -> {:error, {:not_found, "Trust session not found"}}
      {:error, _} = error -> error
    end
  end

  def complete_session(session_id, session_token, %HumanUser{} = human, proof)
      when is_binary(session_id) and is_binary(session_token) and is_map(proof) do
    with %Session{} = session <- Repo.get(Session, session_id),
         true <- valid_approval_token?(session, session_token),
         :ok <- ensure_session_open(session),
         {:ok, updated} <- submit_session_payload(session, proof),
         {:ok, persisted} <- persist_updated_session(session, updated),
         {:ok, finalized} <- maybe_finalize_registered_session(persisted, human) do
      {:ok, serialize_session(finalized)}
    else
      nil -> {:error, {:not_found, "Trust session not found"}}
      false -> {:error, {:not_found, "Trust session not found"}}
      {:error, _} = error -> error
    end
  end

  def store_connector_uri(session_id, connector_uri)
      when is_binary(session_id) and is_binary(connector_uri) do
    with %Session{} = session <- Repo.get(Session, session_id),
         {:ok, updated} <-
           session
           |> Session.update_changeset(%{
             connector_uri: connector_uri,
             deep_link_uri: connector_uri
           })
           |> Repo.update() do
      {:ok, serialize_session(updated)}
    else
      nil -> {:error, {:not_found, "Trust session not found"}}
      {:error, _changeset} -> {:error, {:unavailable, "The World App link could not be saved"}}
    end
  end

  def fail_session(session_id, message) when is_binary(session_id) do
    with %Session{} = session <- Repo.get(Session, session_id),
         {:ok, updated} <-
           session
           |> Session.update_changeset(%{status: "failed", error_text: to_string(message)})
           |> Repo.update() do
      {:ok, serialize_session(updated)}
    else
      nil -> {:error, {:not_found, "Trust session not found"}}
      {:error, _changeset} -> {:error, {:unavailable, "The trust session could not be updated"}}
    end
  end

  def lookup_for_agent(agent_claims) when is_map(agent_claims) do
    with {:ok, identity} <- identity_from_claims(agent_claims) do
      {:ok, trust_lookup(identity)}
    end
  end

  def human_trust_summary(%HumanUser{} = human) do
    %{
      connected: is_binary(human.world_human_id) and human.world_human_id != "",
      world_human_id: human.world_human_id,
      unique_agent_count: unique_agent_count(human.world_human_id),
      connected_at: human.world_verified_at && DateTime.to_iso8601(human.world_verified_at),
      source:
        if(is_binary(human.world_human_id) and human.world_human_id != "",
          do: @default_source,
          else: nil
        )
    }
  end

  def human_trust_summary(_human) do
    %{
      connected: false,
      world_human_id: nil,
      unique_agent_count: 0,
      connected_at: nil,
      source: nil
    }
  end

  defp trust_lookup(identity) do
    case link_for_identity(identity) do
      %Link{} = link ->
        %{
          wallet_address: identity.wallet_address,
          chain_id: identity.chain_id,
          registry_address: identity.registry_address,
          token_id: identity.token_id,
          connected: true,
          world_human_id: link.world_human_id,
          unique_agent_count: unique_agent_count(link.world_human_id),
          connected_at: DateTime.to_iso8601(link.last_verified_at),
          source: link.source
        }

      nil ->
        %{
          wallet_address: identity.wallet_address,
          chain_id: identity.chain_id,
          registry_address: identity.registry_address,
          token_id: identity.token_id,
          connected: false,
          world_human_id: nil,
          unique_agent_count: 0,
          connected_at: nil,
          source: nil
        }
    end
  end

  defp persist_created_session(attrs) do
    %Session{}
    |> Session.create_changeset(attrs)
    |> Repo.insert()
  end

  defp submit_session_payload(session, proof) do
    case registration_module().submit_proof(to_world_session(session), proof, %{submission: :auto}) do
      {:ok, updated} ->
        {:ok, updated}

      {:error, %Error{} = error} ->
        {:error, {:bad_request, Exception.message(error)}}

      {:error, reason} ->
        {:error, {:unavailable, inspect(reason)}}
    end
  end

  defp persist_updated_session(session, updated) do
    normalized = normalize_updated_session(updated)

    session
    |> Session.update_changeset(%{
      status: normalized.status,
      world_human_id: normalized.world_human_id || session.world_human_id,
      error_text: normalized.error_text,
      connector_uri: normalized.connector_uri || session.connector_uri,
      deep_link_uri: normalized.deep_link_uri || session.deep_link_uri
    })
    |> Repo.update()
  end

  defp maybe_finalize_registered_session(
         %Session{status: "registered"} = session,
         %HumanUser{} = human
       ) do
    with {:ok, world_human_id} <- fetch_world_human_id(session),
         :ok <- ensure_human_can_claim_world_id(human, world_human_id),
         {:ok, finalized} <- finalize_registered_session(session, human, world_human_id) do
      {:ok, finalized}
    end
  end

  defp maybe_finalize_registered_session(%Session{} = session, _human), do: {:ok, session}

  defp fetch_world_human_id(%Session{} = session) do
    case session.world_human_id || lookup_world_human_id(session.wallet_address) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:unavailable, "The anonymous human link could not be confirmed yet"}}
    end
  end

  defp lookup_world_human_id(wallet_address) do
    case agent_book_module().lookup_human(wallet_address, @world_network, %{}) do
      {:ok, value} when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp ensure_human_can_claim_world_id(%HumanUser{world_human_id: nil}, _world_human_id), do: :ok
  defp ensure_human_can_claim_world_id(%HumanUser{world_human_id: value}, value), do: :ok

  defp ensure_human_can_claim_world_id(_human, _world_human_id),
    do:
      {:error,
       {:conflict,
        "This signed-in person is already linked to a different human-backed trust record"}}

  defp ensure_world_id_not_claimed_by_other_human(%HumanUser{id: human_id}, world_human_id, opts) do
    lock = Keyword.get(opts, :lock)

    query =
      if is_binary(lock) do
        from human in HumanUser,
          where: human.world_human_id == ^world_human_id and human.id != ^human_id,
          select: human.id,
          limit: 1,
          lock: "FOR UPDATE"
      else
        from human in HumanUser,
          where: human.world_human_id == ^world_human_id and human.id != ^human_id,
          select: human.id,
          limit: 1
      end

    case Repo.one(query) do
      nil ->
        :ok

      _ ->
        {:error,
         {:conflict,
          "This human-backed trust record is already attached to another signed-in person"}}
    end
  end

  defp upsert_link(%Session{} = session, %HumanUser{} = human, world_human_id) do
    identity = %{
      wallet_address: session.wallet_address,
      chain_id: session.chain_id,
      registry_address: session.registry_address,
      token_id: session.token_id
    }

    case link_for_identity(identity) do
      %Link{world_human_id: ^world_human_id} = link ->
        link
        |> Link.changeset(%{
          platform_human_user_id: human.id,
          source: session.source,
          last_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()

      %Link{} ->
        {:error,
         {:conflict,
          "This Regent agent is already linked to a different human-backed trust record"}}

      nil ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        %Link{}
        |> Link.changeset(%{
          wallet_address: session.wallet_address,
          chain_id: session.chain_id,
          registry_address: session.registry_address,
          token_id: session.token_id,
          world_human_id: world_human_id,
          platform_human_user_id: human.id,
          source: session.source,
          first_verified_at: now,
          last_verified_at: now
        })
        |> Repo.insert()
        |> case do
          {:ok, link} ->
            {:ok, link}

          {:error, changeset} ->
            handle_link_insert_conflict(identity, world_human_id, human, session, changeset)
        end
    end
  end

  defp unique_agent_count(nil), do: 0

  defp unique_agent_count(world_human_id) when is_binary(world_human_id) do
    Repo.aggregate(
      from(link in Link, where: link.world_human_id == ^world_human_id),
      :count,
      :id
    )
  end

  defp serialize_session(%Session{} = session, approval_url \\ nil) do
    %{
      session_id: session.session_id,
      status: session.status,
      wallet_address: session.wallet_address,
      chain_id: session.chain_id,
      registry_address: session.registry_address,
      token_id: session.token_id,
      network: session.network,
      source: session.source,
      approval_url: approval_url,
      connector_uri: session.connector_uri,
      deep_link_uri: session.deep_link_uri,
      expires_at: DateTime.to_iso8601(session.expires_at),
      error_text: session.error_text,
      frontend_request: frontend_request(session),
      tx_request: nil,
      trust:
        case link_for_session(session) do
          %Link{} = link ->
            %{
              connected: true,
              world_human_id: link.world_human_id,
              unique_agent_count: unique_agent_count(link.world_human_id),
              connected_at: DateTime.to_iso8601(link.last_verified_at),
              source: link.source
            }

          nil ->
            %{
              connected: false,
              world_human_id: session.world_human_id,
              unique_agent_count: unique_agent_count(session.world_human_id),
              connected_at: nil,
              source: if(session.world_human_id, do: session.source, else: nil)
            }
        end
    }
  end

  defp frontend_request(%Session{app_id: nil}), do: nil

  defp frontend_request(%Session{} = session) do
    %{
      app_id: session.app_id,
      action: session.action,
      signal: session.signal,
      rp_context: session.rp_context,
      allow_legacy_proofs: session.allow_legacy_proofs
    }
  end

  defp link_for_session(%Session{} = session) do
    link_for_identity(%{
      wallet_address: session.wallet_address,
      chain_id: session.chain_id,
      registry_address: session.registry_address,
      token_id: session.token_id
    })
  end

  defp link_for_identity(identity) do
    Repo.get_by(Link,
      wallet_address: identity.wallet_address,
      chain_id: identity.chain_id,
      registry_address: identity.registry_address,
      token_id: identity.token_id
    )
  end

  defp identity_from_claims(claims) do
    with {:ok, wallet_address} <- required_address(Map.get(claims, "wallet_address")),
         {:ok, chain_id} <- required_chain_id(Map.get(claims, "chain_id")),
         {:ok, registry_address} <- required_address(Map.get(claims, "registry_address")),
         {:ok, token_id} <- required_text(Map.get(claims, "token_id")) do
      {:ok,
       %{
         wallet_address: wallet_address,
         chain_id: chain_id,
         registry_address: registry_address,
         token_id: token_id
       }}
    end
  end

  defp normalize_created_session(created, identity, source, approval_token)
       when is_map(created) do
    with {:ok, session_id} <- fetch_required(created, :session_id),
         {:ok, status} <- fetch_required(created, :status),
         {:ok, app_id} <- fetch_required(created, :app_id),
         {:ok, action} <- fetch_required(created, :action),
         {:ok, rp_id} <- fetch_required(created, :rp_id),
         {:ok, signal} <- fetch_required(created, :signal),
         {:ok, rp_context} <- fetch_required(created, :rp_context),
         {:ok, expires_at} <- fetch_required(created, :expires_at) do
      {:ok,
       %{
         session_id: session_id,
         wallet_address: identity.wallet_address,
         chain_id: identity.chain_id,
         registry_address: identity.registry_address,
         token_id: identity.token_id,
         network: @world_network,
         source: source,
         contract_address: Map.get(created, :contract_address),
         relay_url: Map.get(created, :relay_url),
         nonce: Map.get(created, :nonce),
         approval_token_hash: hash_token(approval_token),
         app_id: app_id,
         action: action,
         rp_id: rp_id,
         signal: signal,
         rp_context: rp_context,
         allow_legacy_proofs: Map.get(created, :allow_legacy_proofs, false),
         connector_uri: Map.get(created, :connector_uri),
         deep_link_uri: Map.get(created, :deep_link_uri),
         status: status_string(status),
         world_human_id: Map.get(created, :human_id),
         error_text: Map.get(created, :error_text),
         expires_at: expires_at
       }}
    else
      _ -> {:error, {:unavailable, "The World trust request could not be prepared right now"}}
    end
  end

  defp normalize_updated_session(updated) when is_map(updated) do
    status = status_string(Map.get(updated, :status))

    if status == "proof_ready" do
      error_text =
        case Map.get(updated, :error_text) do
          value when is_binary(value) and value != "" ->
            "This trust request needs a wallet step that is not available in this approval flow. #{value}"

          _ ->
            "This trust request needs a wallet step that is not available in this approval flow."
        end

      %{
        status: "failed",
        world_human_id: Map.get(updated, :human_id),
        error_text: error_text,
        connector_uri: Map.get(updated, :connector_uri),
        deep_link_uri: Map.get(updated, :deep_link_uri)
      }
    else
      %{
        status: status,
        world_human_id: Map.get(updated, :human_id),
        error_text: Map.get(updated, :error_text),
        connector_uri: Map.get(updated, :connector_uri),
        deep_link_uri: Map.get(updated, :deep_link_uri)
      }
    end
  end

  defp same_identity?(%Session{} = session, identity) do
    session.wallet_address == identity.wallet_address and
      session.chain_id == identity.chain_id and
      session.registry_address == identity.registry_address and
      session.token_id == identity.token_id
  end

  defp ensure_session_open(%Session{} = session) do
    cond do
      DateTime.compare(DateTime.utc_now(), session.expires_at) != :lt ->
        {:error, {:conflict, "This trust session expired. Start a new one from the CLI."}}

      session.status != "pending" ->
        {:error, {:conflict, "This trust session is no longer waiting for human approval."}}

      true ->
        :ok
    end
  end

  defp ensure_session_not_expired(%Session{} = session) do
    if DateTime.compare(DateTime.utc_now(), session.expires_at) == :lt do
      :ok
    else
      {:error, {:not_found, "Trust session not found"}}
    end
  end

  defp to_world_session(%Session{} = session) do
    %{
      session_id: session.session_id,
      status: status_atom(session.status),
      agent_address: session.wallet_address,
      network: session.network,
      chain_id: session.chain_id,
      contract_address: session.contract_address,
      relay_url: session.relay_url,
      nonce: session.nonce,
      app_id: session.app_id,
      action: session.action,
      rp_id: session.rp_id,
      signal: session.signal,
      rp_context: session.rp_context,
      connector_uri: session.connector_uri,
      deep_link_uri: session.deep_link_uri,
      expires_at: session.expires_at,
      proof_payload: nil,
      tx_request: nil,
      tx_hash: nil,
      human_id: session.world_human_id,
      error_text: session.error_text
    }
  end

  defp finalize_registered_session(%Session{} = session, %HumanUser{} = human, world_human_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.run(:human, fn repo, _changes ->
      locked_human =
        repo.one!(
          from locked in HumanUser,
            where: locked.id == ^human.id,
            lock: "FOR UPDATE"
        )

      with :ok <- ensure_human_can_claim_world_id(locked_human, world_human_id),
           :ok <-
             ensure_world_id_not_claimed_by_other_human(locked_human, world_human_id,
               lock: "FOR UPDATE"
             ) do
        locked_human
        |> HumanUser.changeset(%{
          world_human_id: world_human_id,
          world_verified_at: now
        })
        |> repo.update()
        |> case do
          {:ok, updated_human} ->
            {:ok, updated_human}

          {:error, changeset} ->
            map_human_update_error(changeset)
        end
      end
    end)
    |> Multi.run(:link, fn _repo, %{human: updated_human} ->
      upsert_link(session, updated_human, world_human_id)
    end)
    |> Multi.run(:session, fn repo, %{human: updated_human} ->
      session
      |> Session.update_changeset(%{
        world_human_id: world_human_id,
        platform_human_user_id: updated_human.id,
        error_text: nil
      })
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{session: finalized}} ->
        {:ok, finalized}

      {:error, _step, {:error, reason}, _changes} ->
        {:error, reason}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp map_human_update_error(%Ecto.Changeset{} = changeset) do
    if Keyword.has_key?(changeset.errors, :world_human_id) do
      {:error,
       {:conflict,
        "This human-backed trust record is already attached to another signed-in person"}}
    else
      {:error, {:unavailable, "The human-backed trust record could not be saved"}}
    end
  end

  defp handle_link_insert_conflict(identity, world_human_id, %HumanUser{} = human, session, _changeset) do
    case link_for_identity(identity) do
      %Link{world_human_id: ^world_human_id} = link ->
        link
        |> Link.changeset(%{
          platform_human_user_id: human.id,
          source: session.source,
          last_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()

      %Link{} ->
        {:error,
         {:conflict,
          "This Regent agent is already linked to a different human-backed trust record"}}

      nil ->
        {:error, {:unavailable, "The Regent agent trust link could not be saved"}}
    end
  end

  defp fetch_required(map, key) do
    case Map.get(map, key) do
      value when value not in [nil, ""] -> {:ok, value}
      _ -> :error
    end
  end

  defp create_approval_token do
    {:ok, Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)}
  end

  defp valid_approval_token?(%Session{} = session, token) do
    hash_token(token) == session.approval_token_hash
  end

  defp hash_token(token) do
    :sha256
    |> :crypto.hash(token)
    |> Base.encode16(case: :lower)
  end

  defp approval_url(base_url, session_id, token) do
    "#{String.trim_trailing(base_url, "/")}/app/trust?session_id=#{URI.encode(session_id)}&token=#{URI.encode(token)}"
  end

  defp normalize_source(value) when is_binary(value) do
    case String.trim(value) do
      "" -> @default_source
      trimmed -> String.slice(trimmed, 0, 80)
    end
  end

  defp normalize_source(_value), do: @default_source

  defp required_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, {:bad_request, "Signed Regent identity is incomplete"}}
      trimmed -> {:ok, trimmed}
    end
  end

  defp required_text(_value), do: {:error, {:bad_request, "Signed Regent identity is incomplete"}}

  defp required_address(value) when is_binary(value) do
    trimmed = String.trim(value)

    if Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, trimmed) do
      {:ok, String.downcase(trimmed)}
    else
      {:error, {:bad_request, "Signed Regent identity is incomplete"}}
    end
  end

  defp required_address(_value),
    do: {:error, {:bad_request, "Signed Regent identity is incomplete"}}

  defp required_chain_id(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp required_chain_id(_value),
    do: {:error, {:bad_request, "Signed Regent identity is incomplete"}}

  defp status_string(value) when is_atom(value), do: Atom.to_string(value)
  defp status_string(value) when is_binary(value), do: value
  defp status_string(_value), do: "failed"

  defp status_atom(value) when is_binary(value) do
    case value do
      "pending" -> :pending
      "proof_ready" -> :proof_ready
      "registered" -> :registered
      _ -> :failed
    end
  end

  defp registration_module do
    Application.get_env(:platform_phx, :agentbook, [])
    |> Keyword.get(:registration_module, AgentWorld.Registration)
  end

  defp agent_book_module do
    Application.get_env(:platform_phx, :agentbook, [])
    |> Keyword.get(:agent_book_module, AgentWorld.AgentBook)
  end
end
