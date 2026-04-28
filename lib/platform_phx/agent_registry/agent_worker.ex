defmodule PlatformPhx.AgentRegistry.AgentWorker do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @openclaw_runner_kinds [
    "openclaw_local_manager",
    "openclaw_local_executor",
    "openclaw_code_agent_local"
  ]
  @codex_runner_kinds ["codex_exec", "codex_app_server"]

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "agent_workers" do
    field :name, :string
    field :agent_kind, :string
    field :worker_role, :string
    field :execution_surface, :string
    field :runner_kind, :string
    field :billing_mode, :string
    field :trust_scope, :string
    field :reported_usage_policy, :string
    field :status, :string, default: "registered"
    field :last_heartbeat_at, :utc_datetime
    field :heartbeat_ttl_seconds, :integer, default: 60
    field :capabilities, {:array, :string}, default: []
    field :version, :string
    field :public_key, :string
    field :siwa_subject, :map, default: %{}
    field :connection_metadata, :map, default: %{}
    field :revoked_at, :utc_datetime

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :agent_profile, PlatformPhx.AgentRegistry.AgentProfile
    belongs_to :runtime_profile, PlatformPhx.RuntimeRegistry.RuntimeProfile

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(worker, attrs) do
    worker
    |> cast(attrs, [
      :company_id,
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
    ])
    |> apply_openclaw_local_defaults()
    |> validate_required([
      :company_id,
      :agent_profile_id,
      :name,
      :agent_kind,
      :worker_role,
      :execution_surface,
      :runner_kind,
      :billing_mode,
      :trust_scope,
      :reported_usage_policy,
      :status
    ])
    |> validate_inclusion(:agent_kind, RwrEnums.agent_kinds())
    |> validate_inclusion(:worker_role, RwrEnums.worker_roles())
    |> validate_inclusion(:execution_surface, RwrEnums.execution_surfaces())
    |> validate_inclusion(:runner_kind, RwrEnums.runner_kinds())
    |> validate_inclusion(:billing_mode, RwrEnums.billing_modes())
    |> validate_inclusion(:trust_scope, RwrEnums.trust_scopes())
    |> validate_inclusion(:reported_usage_policy, RwrEnums.reported_usage_policies())
    |> validate_inclusion(:status, ["registered", "active", "offline", "revoked"])
    |> validate_current_execution_shape()
    |> validate_number(:heartbeat_ttl_seconds, greater_than: 0)
    |> validate_length(:name, max: 120)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:agent_profile_id)
    |> foreign_key_constraint(:runtime_profile_id)
    |> unique_constraint([:company_id, :name])
  end

  defp apply_openclaw_local_defaults(changeset) do
    if openclaw_local?(changeset) do
      changeset
      |> put_default(:billing_mode, "user_local")
      |> put_default(:trust_scope, "local_user_controlled")
      |> put_default(:reported_usage_policy, "self_reported")
    else
      changeset
    end
  end

  defp openclaw_local?(changeset) do
    get_field(changeset, :agent_kind) == "openclaw" and
      get_field(changeset, :execution_surface) == "local_bridge"
  end

  defp put_default(changeset, field, value) do
    if is_nil(get_field(changeset, field)),
      do: put_change(changeset, field, value),
      else: changeset
  end

  defp validate_current_execution_shape(changeset) do
    changeset
    |> validate_openclaw_local_only()
    |> validate_codex_hosted_only()
  end

  defp validate_openclaw_local_only(changeset) do
    if get_field(changeset, :agent_kind) == "openclaw" or
         get_field(changeset, :runner_kind) in @openclaw_runner_kinds do
      changeset
      |> require_field_value(:execution_surface, "local_bridge")
      |> require_field_value(:billing_mode, "user_local")
      |> require_field_value(:trust_scope, "local_user_controlled")
      |> require_field_value(:reported_usage_policy, "self_reported")
    else
      changeset
    end
  end

  defp validate_codex_hosted_only(changeset) do
    if get_field(changeset, :runner_kind) in @codex_runner_kinds do
      changeset
      |> require_field_value(:execution_surface, "hosted_sprite")
      |> require_field_value(:billing_mode, "platform_hosted")
      |> require_field_value(:trust_scope, "platform_hosted")
      |> require_field_value(:reported_usage_policy, "platform_metered")
    else
      changeset
    end
  end

  defp require_field_value(changeset, field, expected) do
    if get_field(changeset, field) == expected do
      changeset
    else
      add_error(changeset, field, "must be #{expected}")
    end
  end
end
