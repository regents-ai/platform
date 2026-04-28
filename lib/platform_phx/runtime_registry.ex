defmodule PlatformPhx.RuntimeRegistry do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.Repo
  alias PlatformPhx.RuntimeRegistry.RuntimeCheckpoint
  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.RuntimeRegistry.RuntimeService
  alias PlatformPhx.RuntimeRegistry.RuntimeUsageSnapshot
  alias PlatformPhx.RuntimeRegistry.SpritesBootstrap
  alias PlatformPhx.RuntimeRegistry.SpritesClient
  alias PlatformPhx.RuntimeRegistry.SpritesPolicy
  alias PlatformPhx.RuntimeRegistry.SpritesService

  @hosted_codex_runner_kinds ["codex_exec", "codex_app_server"]
  @hosted_sprite_meter_key "sprite_runtime_seconds"

  def get_runtime_profile(id), do: Repo.get(RuntimeProfile, id)

  def get_runtime_service(id), do: Repo.get(RuntimeService, id)

  def get_runtime_checkpoint(id), do: Repo.get(RuntimeCheckpoint, id)

  def create_runtime_profile(attrs) do
    %RuntimeProfile{}
    |> RuntimeProfile.changeset(attrs)
    |> Repo.insert()
  end

  def list_runtime_profiles(company_id) do
    RuntimeProfile
    |> where([profile], profile.company_id == ^company_id)
    |> order_by([profile], asc: profile.name)
    |> Repo.all()
  end

  def list_runtime_profiles_with_details(company_id) do
    RuntimeProfile
    |> where([profile], profile.company_id == ^company_id)
    |> order_by([profile], asc: profile.name)
    |> preload([:platform_agent])
    |> Repo.all()
  end

  def get_runtime_profile(company_id, runtime_profile_id) do
    RuntimeProfile
    |> where([profile], profile.company_id == ^company_id)
    |> where([profile], profile.id == ^runtime_profile_id)
    |> preload([:platform_agent])
    |> Repo.one()
  end

  def update_runtime_profile_status(%RuntimeProfile{} = profile, status) do
    profile
    |> RuntimeProfile.changeset(%{status: status})
    |> Repo.update()
  end

  def register_hosted_codex_runtime(company_id, platform_agent_id, attrs \\ %{}) do
    with {:ok, %Agent{} = agent} <- fetch_company_agent(company_id, platform_agent_id) do
      attrs =
        attrs
        |> Map.new()
        |> Map.merge(%{
          company_id: company_id,
          platform_agent_id: agent.id,
          runner_kind: Map.get(attrs, :runner_kind, Map.get(attrs, "runner_kind", "codex_exec")),
          execution_surface: "hosted_sprite",
          billing_mode: "platform_hosted",
          status: Map.get(attrs, :status, Map.get(attrs, "status", "active")),
          visibility: Map.get(attrs, :visibility, Map.get(attrs, "visibility", "operator")),
          metadata: hosted_codex_metadata(agent, attrs)
        })
        |> put_new_attr(:name, default_hosted_codex_name(agent))

      case Map.fetch(attrs, :runner_kind) do
        {:ok, runner_kind} when runner_kind in @hosted_codex_runner_kinds ->
          create_runtime_profile(attrs)

        {:ok, _runner_kind} ->
          {:error, {:bad_request, "Hosted Codex runtimes must use a hosted Codex runner"}}

        :error ->
          {:error, {:bad_request, "Hosted Codex runtimes must use a hosted Codex runner"}}
      end
    end
  end

  def discover_hosted_codex_runtimes(company_id) do
    RuntimeProfile
    |> where([profile], profile.company_id == ^company_id)
    |> where([profile], profile.execution_surface == "hosted_sprite")
    |> where([profile], profile.runner_kind in ^@hosted_codex_runner_kinds)
    |> order_by([profile], asc: profile.name)
    |> preload([:platform_agent])
    |> Repo.all()
  end

  def hosted_runtime_availability(%RuntimeProfile{} = profile) do
    profile = Repo.preload(profile, :platform_agent)

    case profile.platform_agent do
      %Agent{} = agent ->
        billing_account = billing_account_for_agent(agent)
        metering_status = AgentPlatform.effective_metering_status(agent, billing_account)

        if metering_status in ["paid", "trialing"] and agent.desired_runtime_state != "paused" do
          %{available?: true, status: "available", metering_status: metering_status}
        else
          %{available?: false, status: "paused", metering_status: metering_status}
        end

      _missing ->
        %{available?: false, status: "unavailable", metering_status: "paused"}
    end
  end

  def create_runtime_service(attrs) do
    %RuntimeService{}
    |> RuntimeService.changeset(attrs)
    |> Repo.insert()
  end

  def list_runtime_services(company_id) do
    RuntimeService
    |> where([service], service.company_id == ^company_id)
    |> order_by([service], asc: service.name, asc: service.id)
    |> Repo.all()
  end

  def list_runtime_services_for_profile(runtime_profile_id) do
    RuntimeService
    |> where([service], service.runtime_profile_id == ^runtime_profile_id)
    |> order_by([service], asc: service.name, asc: service.id)
    |> Repo.all()
  end

  def provision_sprites_runtime(%RuntimeProfile{} = profile) do
    SpritesBootstrap.provision_runtime(profile)
  end

  def sync_sprites_services(%RuntimeProfile{} = profile) do
    SpritesService.sync_services(profile)
  end

  def start_sprites_service(%RuntimeService{} = service),
    do: SpritesService.start_service(service)

  def stop_sprites_service(%RuntimeService{} = service), do: SpritesService.stop_service(service)

  def observe_sprites_service(%RuntimeService{} = service),
    do: SpritesService.observe_service(service)

  def exec_sprites_runtime(%RuntimeProfile{} = profile, attrs) do
    with {:ok, runtime_id} <- provider_runtime_id(profile) do
      SpritesClient.exec(runtime_id, Map.new(attrs))
    end
  end

  def list_runtime_services(company_id, runtime_profile_id) do
    RuntimeService
    |> where([service], service.company_id == ^company_id)
    |> where([service], service.runtime_profile_id == ^runtime_profile_id)
    |> order_by([service], asc: service.name, asc: service.id)
    |> Repo.all()
  end

  def create_runtime_checkpoint(attrs) do
    %RuntimeCheckpoint{}
    |> RuntimeCheckpoint.changeset(attrs)
    |> Repo.insert()
  end

  def list_runtime_checkpoints(company_id) do
    RuntimeCheckpoint
    |> where([checkpoint], checkpoint.company_id == ^company_id)
    |> order_by([checkpoint], desc: checkpoint.updated_at, desc: checkpoint.id)
    |> Repo.all()
  end

  def create_sprites_checkpoint(%RuntimeProfile{} = profile, attrs) do
    with {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, checkpoint} <- SpritesClient.create_checkpoint(runtime_id, Map.new(attrs)) do
      attrs =
        attrs
        |> Map.new()
        |> Map.merge(%{
          company_id: profile.company_id,
          runtime_profile_id: profile.id,
          checkpoint_ref: checkpoint["checkpoint_ref"] || checkpoint["id"],
          status: "ready",
          protected: true,
          checkpoint_kind: "filesystem",
          captured_at: DateTime.utc_now() |> DateTime.truncate(:second),
          metadata:
            checkpoint
            |> Map.get("metadata", %{})
            |> SpritesPolicy.checkpoint_metadata()
            |> Map.merge(%{"sprites_checkpoint" => checkpoint})
        })
        |> put_new_attr(:checkpoint_ref, checkpoint["checkpoint_ref"] || checkpoint["id"])

      create_runtime_checkpoint(attrs)
    end
  end

  def create_sprites_checkpoint_for_row(%RuntimeCheckpoint{status: "ready"} = checkpoint),
    do: {:ok, checkpoint}

  def create_sprites_checkpoint_for_row(%RuntimeCheckpoint{} = checkpoint) do
    profile = Repo.get(RuntimeProfile, checkpoint.runtime_profile_id)

    with %RuntimeProfile{} = profile <- profile,
         {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, payload} <-
           SpritesClient.create_checkpoint(runtime_id, %{
             "checkpoint_ref" => checkpoint.checkpoint_ref,
             "checkpoint_kind" => "filesystem"
           }) do
      checkpoint
      |> RuntimeCheckpoint.changeset(%{
        status: "ready",
        protected: true,
        checkpoint_kind: "filesystem",
        captured_at: DateTime.utc_now() |> DateTime.truncate(:second),
        metadata:
          checkpoint.metadata
          |> SpritesPolicy.checkpoint_metadata()
          |> Map.merge(%{"sprites_checkpoint" => payload})
      })
      |> Repo.update()
    else
      nil -> {:error, :runtime_profile_not_found}
      error -> error
    end
  end

  def restore_sprites_checkpoint(%RuntimeCheckpoint{restore_status: "succeeded"} = checkpoint),
    do: {:ok, checkpoint}

  def restore_sprites_checkpoint(%RuntimeCheckpoint{} = checkpoint) do
    profile = Repo.get(RuntimeProfile, checkpoint.runtime_profile_id)

    with %RuntimeProfile{} = profile <- profile,
         {:ok, runtime_id} <- provider_runtime_id(profile),
         {:ok, payload} <- SpritesClient.restore_checkpoint(runtime_id, checkpoint.checkpoint_ref) do
      checkpoint
      |> RuntimeCheckpoint.changeset(%{
        restore_status: "succeeded",
        restored_at: DateTime.utc_now() |> DateTime.truncate(:second),
        metadata:
          Map.merge(checkpoint.metadata || %{}, %{
            "restore" => payload,
            "checkpoint_kind" => "filesystem",
            "checkpoint_semantics" => "filesystem_rollback_point"
          })
      })
      |> Repo.update()
    else
      nil ->
        {:error, :runtime_profile_not_found}

      {:error, reason} = error ->
        mark_restore_failed(checkpoint, reason)
        error
    end
  end

  def observe_sprites_capacity(%RuntimeProfile{} = profile) do
    SpritesBootstrap.observe_capacity(profile)
  end

  def get_runtime_checkpoint(company_id, runtime_profile_id, checkpoint_id) do
    RuntimeCheckpoint
    |> where([checkpoint], checkpoint.company_id == ^company_id)
    |> where([checkpoint], checkpoint.runtime_profile_id == ^runtime_profile_id)
    |> where([checkpoint], checkpoint.id == ^checkpoint_id)
    |> Repo.one()
  end

  def create_hosted_sprite_checkpoint(%RuntimeProfile{} = profile, attrs) do
    profile = Repo.preload(profile, :platform_agent)

    if hosted_sprite_profile?(profile) do
      attrs
      |> Map.new()
      |> Map.merge(%{
        company_id: profile.company_id,
        runtime_profile_id: profile.id,
        protected: true,
        checkpoint_kind: "filesystem",
        metadata: SpritesPolicy.checkpoint_metadata(attr(attrs, :metadata, %{}))
      })
      |> put_new_attr(:status, "ready")
      |> create_runtime_checkpoint()
    else
      {:error, {:bad_request, "Only hosted Sprite runtimes can create protected checkpoints"}}
    end
  end

  def create_usage_snapshot(attrs) do
    %RuntimeUsageSnapshot{}
    |> RuntimeUsageSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  def list_usage_snapshots(company_id) do
    RuntimeUsageSnapshot
    |> where([snapshot], snapshot.company_id == ^company_id)
    |> order_by([snapshot], desc: snapshot.snapshot_at, desc: snapshot.id)
    |> Repo.all()
  end

  def create_sprites_usage_snapshot(%RuntimeProfile{} = profile, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, updated_profile} <- observe_sprites_capacity(profile) do
      create_usage_snapshot(%{
        company_id: updated_profile.company_id,
        runtime_profile_id: updated_profile.id,
        snapshot_at: attr(attrs, :snapshot_at, now),
        provider: "sprites",
        compute_state: updated_profile.status,
        active_seconds: attr(attrs, :active_seconds, 0),
        storage_bytes: updated_profile.observed_storage_bytes || 0,
        reported_memory_mb: updated_profile.observed_memory_mb,
        reported_storage_bytes: updated_profile.observed_storage_bytes,
        estimated_cost_usd: attr(attrs, :estimated_cost_usd, Decimal.new("0")),
        metadata:
          Map.merge(attr(attrs, :metadata, %{}), %{
            "observed_capacity_at" => updated_profile.observed_capacity_at,
            "rate_limit_upgrade_url" => updated_profile.rate_limit_upgrade_url
          })
      })
    end
  end

  def record_hosted_sprite_usage(%RuntimeProfile{} = profile, attrs) do
    profile = Repo.preload(profile, :platform_agent)

    with true <- hosted_sprite_profile?(profile),
         %Agent{} = agent <- profile.platform_agent,
         %BillingAccount{} = billing_account <- billing_account_for_agent(agent) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      window_ended_at = attr(attrs, :window_ended_at, now)
      active_seconds = attr(attrs, :active_seconds, 0)

      window_started_at =
        attr(attrs, :window_started_at, DateTime.add(window_ended_at, -active_seconds, :second))

      amount_usd_cents = attr(attrs, :amount_usd_cents, 0)

      Multi.new()
      |> Multi.run(:billing_account, fn repo, _changes ->
        account =
          repo.one!(
            from account in BillingAccount,
              where: account.id == ^billing_account.id,
              lock: "FOR UPDATE"
          )

        next_balance = max((account.runtime_credit_balance_usd_cents || 0) - amount_usd_cents, 0)

        account
        |> BillingAccount.changeset(%{runtime_credit_balance_usd_cents: next_balance})
        |> repo.update()
      end)
      |> Multi.insert(:sprite_usage_record, fn _changes ->
        SpriteUsageRecord.changeset(%SpriteUsageRecord{}, %{
          billing_account_id: billing_account.id,
          agent_id: agent.id,
          meter_key: attr(attrs, :meter_key, @hosted_sprite_meter_key),
          usage_seconds: active_seconds,
          amount_usd_cents: amount_usd_cents,
          window_started_at: window_started_at,
          window_ended_at: window_ended_at,
          status: "pending",
          stripe_sync_attempt_count: 0
        })
      end)
      |> Multi.insert(:billing_ledger_entry, fn %{sprite_usage_record: usage_record} ->
        BillingLedgerEntry.changeset(%BillingLedgerEntry{}, %{
          billing_account_id: billing_account.id,
          agent_id: agent.id,
          entry_type: "runtime_debit",
          amount_usd_cents: -amount_usd_cents,
          description: "Sprite runtime charge.",
          source_ref: "sprite-usage:#{usage_record.id}",
          effective_at: window_ended_at
        })
      end)
      |> Multi.insert(:usage_snapshot, fn %{sprite_usage_record: usage_record} ->
        RuntimeUsageSnapshot.changeset(%RuntimeUsageSnapshot{}, %{
          company_id: profile.company_id,
          runtime_profile_id: profile.id,
          platform_sprite_usage_record_id: usage_record.id,
          snapshot_at: attr(attrs, :snapshot_at, window_ended_at),
          provider: "sprites",
          compute_state: attr(attrs, :compute_state, "active"),
          active_seconds: active_seconds,
          storage_bytes: attr(attrs, :storage_bytes, 0),
          estimated_cost_usd: cents_to_decimal(amount_usd_cents),
          metadata: Map.merge(attr(attrs, :metadata, %{}), %{"billing_mode" => "platform_hosted"})
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{usage_snapshot: snapshot, sprite_usage_record: usage_record}} ->
          {:ok, %{snapshot: snapshot, sprite_usage_record: usage_record}}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    else
      false ->
        {:error, {:bad_request, "Hosted usage can only be recorded for hosted Sprite runtimes"}}

      nil ->
        {:error, {:payment_required, "Hosted Sprite usage requires a billing account"}}
    end
  end

  def record_local_openclaw_usage(%RuntimeProfile{} = profile, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.merge(%{
        company_id: profile.company_id,
        runtime_profile_id: profile.id,
        provider: "openclaw_local",
        estimated_cost_usd: Decimal.new("0"),
        metadata: Map.merge(attr(attrs, :metadata, %{}), %{"billing_mode" => "user_local"})
      })
      |> put_new_attr(:snapshot_at, DateTime.utc_now() |> DateTime.truncate(:second))

    create_usage_snapshot(attrs)
  end

  defp fetch_company_agent(company_id, platform_agent_id) do
    case Repo.get_by(Agent, id: platform_agent_id, company_id: company_id) do
      %Agent{} = agent -> {:ok, agent}
      nil -> {:error, {:not_found, "Platform agent not found for this company"}}
    end
  end

  def provider_runtime_id(%RuntimeProfile{provider_runtime_id: runtime_id})
      when is_binary(runtime_id) and runtime_id != "",
      do: {:ok, runtime_id}

  def provider_runtime_id(_profile), do: {:error, :runtime_not_provisioned}

  defp mark_restore_failed(%RuntimeCheckpoint{} = checkpoint, reason) do
    checkpoint
    |> RuntimeCheckpoint.changeset(%{
      restore_status: "failed",
      metadata: Map.merge(checkpoint.metadata || %{}, %{"restore_error" => inspect(reason)})
    })
    |> Repo.update()
  end

  defp billing_account_for_agent(%Agent{owner_human_id: owner_human_id}) do
    Repo.one(from account in BillingAccount, where: account.human_user_id == ^owner_human_id)
  end

  defp hosted_sprite_profile?(%RuntimeProfile{
         execution_surface: "hosted_sprite",
         billing_mode: "platform_hosted",
         runner_kind: runner_kind,
         platform_agent: %Agent{}
       })
       when runner_kind in @hosted_codex_runner_kinds,
       do: true

  defp hosted_sprite_profile?(_profile), do: false

  defp default_hosted_codex_name(%Agent{name: name}) when is_binary(name),
    do: "#{name} Hosted Codex"

  defp default_hosted_codex_name(_agent), do: "Hosted Codex"

  defp hosted_codex_metadata(%Agent{} = agent, attrs) do
    attr(attrs, :metadata, %{})
    |> Map.merge(%{
      "billing_mode" => "platform_hosted",
      "platform_agent_id" => agent.id,
      "sprite_name" => agent.sprite_name,
      "sprite_service_name" => agent.sprite_service_name
    })
  end

  defp put_new_attr(attrs, key, value) do
    if Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key)) do
      attrs
    else
      Map.put(attrs, key, value)
    end
  end

  defp attr(attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp cents_to_decimal(cents) when is_integer(cents) do
    cents
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100))
  end

  defp cents_to_decimal(_cents), do: Decimal.new("0")
end
