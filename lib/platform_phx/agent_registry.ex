defmodule PlatformPhx.AgentRegistry do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentRegistry.AgentProfile
  alias PlatformPhx.AgentRegistry.AgentRelationship
  alias PlatformPhx.AgentRegistry.AgentWorker
  alias PlatformPhx.AgentRegistry.WorkerAssignment
  alias PlatformPhx.Repo
  alias PlatformPhx.WorkRuns.WorkRun

  @active_assignment_statuses ["claimed", "leased"]

  @openclaw_local_defaults %{
    agent_kind: "openclaw",
    billing_mode: "user_local",
    trust_scope: "local_user_controlled",
    reported_usage_policy: "self_reported",
    execution_surface: "local_bridge"
  }
  @worker_registration_fields [
    :agent_profile_id,
    :runtime_profile_id,
    :name,
    :agent_kind,
    :worker_role,
    :execution_surface,
    :runner_kind,
    :billing_mode,
    :trust_scope,
    :reported_usage_policy,
    :status,
    :last_heartbeat_at,
    :heartbeat_ttl_seconds,
    :capabilities,
    :version,
    :public_key,
    :siwa_subject,
    :connection_metadata,
    :revoked_at
  ]

  def create_agent_profile(attrs) do
    %AgentProfile{}
    |> AgentProfile.changeset(attrs)
    |> Repo.insert()
  end

  def list_agent_profiles(company_id) do
    AgentProfile
    |> where([profile], profile.company_id == ^company_id)
    |> order_by([profile], asc: profile.name)
    |> Repo.all()
  end

  def list_agent_profiles_with_workers(company_id) do
    AgentProfile
    |> where([profile], profile.company_id == ^company_id)
    |> order_by([profile], asc: profile.name)
    |> preload([:created_by_human])
    |> Repo.all()
  end

  def register_worker(attrs) do
    %AgentWorker{}
    |> AgentWorker.changeset(attrs)
    |> Repo.insert()
  end

  def register_worker(company_id, attrs, _auth_context) do
    attrs
    |> Map.new()
    |> Map.put(:company_id, company_id)
    |> register_worker()
  end

  def register_openclaw_worker(company_id, attrs, auth_context) do
    attrs =
      attrs
      |> atomize_worker_attrs()
      |> put_openclaw_local_defaults()

    register_worker(company_id, attrs, auth_context)
  end

  def list_workers(company_id) do
    mark_stale_workers(company_id)

    AgentWorker
    |> where([worker], worker.company_id == ^company_id)
    |> order_by([worker], asc: worker.name)
    |> Repo.all()
  end

  def list_workers_with_details(company_id) do
    mark_stale_workers(company_id)

    AgentWorker
    |> where([worker], worker.company_id == ^company_id)
    |> order_by([worker], asc: worker.name)
    |> preload([:agent_profile, :runtime_profile])
    |> Repo.all()
  end

  def heartbeat_worker(company_id, worker_id, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Map.new(attrs)

    case get_worker(company_id, worker_id) do
      nil ->
        {:error, :not_found}

      worker ->
        worker
        |> AgentWorker.changeset(%{
          status: Map.get(attrs, :status, Map.get(attrs, "status", "active")),
          last_heartbeat_at: now,
          connection_metadata:
            Map.get(
              attrs,
              :connection_metadata,
              Map.get(attrs, "connection_metadata", worker.connection_metadata)
            )
        })
        |> Repo.update()
    end
  end

  def get_worker(company_id, worker_id) do
    AgentWorker
    |> where([worker], worker.company_id == ^company_id and worker.id == ^worker_id)
    |> Repo.one()
  end

  def create_relationship(attrs) do
    %AgentRelationship{}
    |> AgentRelationship.changeset(attrs)
    |> Repo.insert()
  end

  def create_agent_relationship(company_id, attrs) do
    attrs
    |> Map.new()
    |> Map.put(:company_id, company_id)
    |> ensure_relationship_members_same_company(company_id)
    |> case do
      {:ok, scoped_attrs} -> create_relationship(scoped_attrs)
      {:error, reason} -> {:error, reason}
    end
  end

  def create_agent_relationship(company_id, source_id, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put(:company_id, company_id)

    with :ok <- ensure_relationship_source_matches_path(attrs, source_id),
         {:ok, scoped_attrs} <- ensure_relationship_members_same_company(attrs, company_id) do
      create_relationship(scoped_attrs)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def list_relationships(company_id) do
    AgentRelationship
    |> where([relationship], relationship.company_id == ^company_id)
    |> order_by([relationship], asc: relationship.id)
    |> Repo.all()
  end

  def list_relationships_for_member(company_id, member_id) do
    AgentRelationship
    |> where([relationship], relationship.company_id == ^company_id)
    |> where(
      [relationship],
      relationship.source_agent_profile_id == ^member_id or
        relationship.source_worker_id == ^member_id or
        relationship.target_agent_profile_id == ^member_id or
        relationship.target_worker_id == ^member_id
    )
    |> order_by([relationship], asc: relationship.id)
    |> Repo.all()
  end

  def get_relationship(company_id, relationship_id) do
    AgentRelationship
    |> where(
      [relationship],
      relationship.company_id == ^company_id and relationship.id == ^relationship_id
    )
    |> Repo.one()
  end

  def delete_relationship(company_id, relationship_id) do
    case get_relationship(company_id, relationship_id) do
      %AgentRelationship{} = relationship -> Repo.delete(relationship)
      nil -> {:error, :not_found}
    end
  end

  def assign_worker(attrs) do
    %WorkerAssignment{}
    |> WorkerAssignment.changeset(attrs)
    |> Repo.insert()
  end

  def create_worker_assignment(company_id, worker_id, attrs) do
    with %AgentWorker{} <- get_worker(company_id, worker_id),
         :ok <- work_run_assignable_to_worker?(company_id, worker_id, attrs) do
      attrs
      |> Map.new()
      |> Map.put(:company_id, company_id)
      |> Map.put(:worker_id, worker_id)
      |> assign_worker()
    else
      nil -> {:error, :worker_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp work_run_assignable_to_worker?(company_id, worker_id, attrs) do
    case Map.get(attrs, :work_run_id) || Map.get(attrs, "work_run_id") do
      nil ->
        {:error, :run_not_found}

      run_id ->
        case Repo.get_by(WorkRun, company_id: company_id, id: run_id) do
          %WorkRun{worker_id: ^worker_id} -> :ok
          %WorkRun{} -> {:error, :run_worker_mismatch}
          nil -> {:error, :run_not_found}
        end
    end
  end

  def list_worker_assignments(company_id, worker_id, opts \\ []) do
    release_expired_leases(company_id, worker_id)

    statuses = Keyword.get(opts, :statuses, ["available", "leased", "claimed"])

    WorkerAssignment
    |> where(
      [assignment],
      assignment.company_id == ^company_id and assignment.worker_id == ^worker_id and
        assignment.status in ^statuses
    )
    |> order_by([assignment], asc: assignment.created_at, asc: assignment.id)
    |> Repo.all()
  end

  def claim_worker_assignment(company_id, worker_id, assignment_id, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    leased_until = Keyword.get(opts, :leased_until)

    release_expired_leases(company_id, worker_id)

    WorkerAssignment
    |> where(
      [assignment],
      assignment.company_id == ^company_id and assignment.worker_id == ^worker_id and
        assignment.id == ^assignment_id and assignment.status in ["available", "leased"]
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      assignment ->
        assignment
        |> WorkerAssignment.changeset(%{
          status: "claimed",
          claimed_at: now,
          leased_until: leased_until
        })
        |> Repo.update()
    end
  end

  def release_worker_assignment(company_id, worker_id, assignment_id) do
    complete_or_release_assignment(company_id, worker_id, assignment_id, "released")
  end

  def complete_worker_assignment(company_id, worker_id, assignment_id) do
    complete_or_release_assignment(company_id, worker_id, assignment_id, "completed")
  end

  def claim_worker_assignment_by_id(company_id, assignment_id, opts \\ []) do
    case get_worker_assignment(company_id, assignment_id) do
      %WorkerAssignment{} = assignment ->
        claim_worker_assignment(company_id, assignment.worker_id, assignment.id, opts)

      nil ->
        {:error, :not_found}
    end
  end

  def get_worker_assignment(company_id, assignment_id) do
    WorkerAssignment
    |> where(
      [assignment],
      assignment.company_id == ^company_id and assignment.id == ^assignment_id
    )
    |> Repo.one()
  end

  def list_execution_pool(company_id, manager_agent_or_worker_id, opts \\ []) do
    mark_stale_workers(company_id)

    company_id
    |> eligible_execution_workers(
      manager_agent_or_worker_id,
      Keyword.get(opts, :delegation_payload, %{})
    )
  end

  def eligible_execution_workers(company_id, manager_agent_or_worker_id, delegation_payload) do
    mark_stale_workers(company_id)

    relationships = active_execution_relationships(company_id, manager_agent_or_worker_id)

    direct_worker_ids =
      company_id
      |> then(fn _company_id -> relationships end)
      |> Enum.flat_map(&relationship_worker_ids/1)
      |> Enum.uniq()

    profile_ids =
      company_id
      |> then(fn _company_id -> relationships end)
      |> Enum.flat_map(&relationship_profile_ids/1)
      |> Enum.uniq()

    AgentWorker
    |> where([worker], worker.company_id == ^company_id)
    |> where([worker], worker.worker_role in ["executor", "hybrid"])
    |> where([worker], worker.status in ["registered", "active"])
    |> where(
      [worker],
      worker.id in ^direct_worker_ids or worker.agent_profile_id in ^profile_ids
    )
    |> order_by([worker], asc: worker.name, asc: worker.id)
    |> Repo.all()
    |> filter_by_delegation_payload(delegation_payload)
    |> filter_by_relationship_capacity(relationships)
  end

  def mark_stale_workers(company_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    AgentWorker
    |> where([worker], worker.company_id == ^company_id)
    |> where([worker], worker.status == "active")
    |> Repo.all()
    |> Enum.each(fn worker ->
      if worker_stale?(worker, now) do
        worker
        |> AgentWorker.changeset(%{status: "offline"})
        |> Repo.update()
      end
    end)

    :ok
  end

  defp active_execution_relationships(company_id, manager_agent_or_worker_id) do
    AgentRelationship
    |> where([relationship], relationship.company_id == ^company_id)
    |> where([relationship], relationship.status == "active")
    |> where(
      [relationship],
      relationship.relationship_kind in [
        "preferred_executor",
        "can_delegate_to",
        "manager_of",
        "reports_to"
      ]
    )
    |> where(
      [relationship],
      (relationship.relationship_kind in ["preferred_executor", "can_delegate_to", "manager_of"] and
         (relationship.source_agent_profile_id == ^manager_agent_or_worker_id or
            relationship.source_worker_id == ^manager_agent_or_worker_id)) or
        (relationship.relationship_kind == "reports_to" and
           (relationship.target_agent_profile_id == ^manager_agent_or_worker_id or
              relationship.target_worker_id == ^manager_agent_or_worker_id))
    )
    |> Repo.all()
  end

  defp complete_or_release_assignment(company_id, worker_id, assignment_id, status) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    WorkerAssignment
    |> where(
      [assignment],
      assignment.company_id == ^company_id and assignment.worker_id == ^worker_id and
        assignment.id == ^assignment_id and
        assignment.status in ["available", "leased", "claimed"]
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      assignment ->
        assignment
        |> WorkerAssignment.changeset(%{
          status: status,
          released_at: now,
          leased_until: nil
        })
        |> Repo.update()
    end
  end

  defp release_expired_leases(company_id, worker_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    WorkerAssignment
    |> where(
      [assignment],
      assignment.company_id == ^company_id and assignment.worker_id == ^worker_id and
        assignment.status == "leased" and not is_nil(assignment.leased_until) and
        assignment.leased_until < ^now
    )
    |> Repo.all()
    |> Enum.each(fn assignment ->
      assignment
      |> WorkerAssignment.changeset(%{status: "available", leased_until: nil, released_at: nil})
      |> Repo.update()
    end)

    :ok
  end

  defp worker_stale?(%AgentWorker{last_heartbeat_at: nil}, _now), do: false

  defp worker_stale?(%AgentWorker{} = worker, now) do
    DateTime.diff(now, worker.last_heartbeat_at, :second) > worker.heartbeat_ttl_seconds
  end

  defp filter_by_delegation_payload(workers, payload) when is_map(payload) do
    workers
    |> filter_by_payload_value(payload, :runner_kind, &(&1.runner_kind == &2))
    |> filter_by_payload_value(payload, :execution_surface, &(&1.execution_surface == &2))
    |> filter_by_payload_value(payload, :status, &(&1.status == &2))
    |> filter_by_required_capabilities(required_capabilities(payload))
  end

  defp filter_by_delegation_payload(workers, _payload), do: workers

  defp filter_by_payload_value(workers, payload, field, predicate) do
    value = Map.get(payload, field) || Map.get(payload, Atom.to_string(field))

    case value do
      nil -> workers
      "" -> workers
      "manager_decides" -> workers
      value -> Enum.filter(workers, &predicate.(&1, value))
    end
  end

  defp required_capabilities(payload) do
    Map.get(payload, :required_capabilities) ||
      Map.get(payload, "required_capabilities") ||
      Map.get(payload, :capabilities) ||
      Map.get(payload, "capabilities") ||
      []
  end

  defp filter_by_required_capabilities(workers, []), do: workers

  defp filter_by_required_capabilities(workers, capabilities) when is_list(capabilities) do
    Enum.filter(workers, fn worker ->
      worker_capabilities = MapSet.new(worker.capabilities || [])

      capabilities
      |> Enum.reject(&is_nil/1)
      |> Enum.all?(&MapSet.member?(worker_capabilities, &1))
    end)
  end

  defp filter_by_required_capabilities(workers, _capabilities), do: workers

  defp filter_by_relationship_capacity(workers, relationships) do
    workers
    |> Enum.filter(fn worker ->
      relationships
      |> Enum.filter(&relationship_targets_worker?(&1, worker))
      |> Enum.any?(&worker_under_relationship_capacity?(worker, &1))
    end)
  end

  defp relationship_targets_worker?(relationship, worker) do
    worker.id in relationship_worker_ids(relationship) or
      worker.agent_profile_id in relationship_profile_ids(relationship)
  end

  defp worker_under_relationship_capacity?(worker, relationship) do
    max_parallel_runs = relationship.max_parallel_runs || 1

    active_count =
      WorkerAssignment
      |> where(
        [assignment],
        assignment.company_id == ^worker.company_id and assignment.worker_id == ^worker.id and
          assignment.status in ^@active_assignment_statuses
      )
      |> Repo.aggregate(:count, :id)

    active_count < max_parallel_runs
  end

  defp relationship_worker_ids(%{relationship_kind: "reports_to"} = relationship) do
    [relationship.source_worker_id]
    |> Enum.reject(&is_nil/1)
  end

  defp relationship_worker_ids(relationship) do
    [relationship.target_worker_id]
    |> Enum.reject(&is_nil/1)
  end

  defp relationship_profile_ids(%{relationship_kind: "reports_to"} = relationship) do
    [relationship.source_agent_profile_id]
    |> Enum.reject(&is_nil/1)
  end

  defp relationship_profile_ids(relationship) do
    [relationship.target_agent_profile_id]
    |> Enum.reject(&is_nil/1)
  end

  defp put_openclaw_local_defaults(attrs) do
    Enum.reduce(@openclaw_local_defaults, attrs, fn {field, value}, normalized ->
      Map.put_new(normalized, field, value)
    end)
  end

  defp ensure_relationship_members_same_company(attrs, company_id) do
    checks = [
      {:source_agent_profile_id, AgentProfile},
      {:target_agent_profile_id, AgentProfile},
      {:source_worker_id, AgentWorker},
      {:target_worker_id, AgentWorker}
    ]

    if Enum.all?(checks, fn {field, schema} ->
         member_in_company?(attrs, field, schema, company_id)
       end) do
      {:ok, attrs}
    else
      {:error, :cross_company_relationship}
    end
  end

  defp ensure_relationship_source_matches_path(attrs, source_id) do
    source_ids =
      [
        Map.get(attrs, :source_agent_profile_id) || Map.get(attrs, "source_agent_profile_id"),
        Map.get(attrs, :source_worker_id) || Map.get(attrs, "source_worker_id")
      ]
      |> Enum.reject(&is_nil/1)

    if Enum.any?(source_ids, &(to_string(&1) == to_string(source_id))) do
      :ok
    else
      {:error, :relationship_source_mismatch}
    end
  end

  defp member_in_company?(attrs, field, schema, company_id) do
    case Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) do
      nil ->
        true

      id ->
        schema
        |> where([record], record.id == ^id and record.company_id == ^company_id)
        |> Repo.exists?()
    end
  end

  defp atomize_worker_attrs(attrs) do
    Enum.reduce(@worker_registration_fields, %{}, fn field, normalized ->
      string_field = Atom.to_string(field)

      cond do
        Map.has_key?(attrs, field) ->
          Map.put(normalized, field, Map.fetch!(attrs, field))

        Map.has_key?(attrs, string_field) ->
          Map.put(normalized, field, Map.fetch!(attrs, string_field))

        true ->
          normalized
      end
    end)
  end
end
