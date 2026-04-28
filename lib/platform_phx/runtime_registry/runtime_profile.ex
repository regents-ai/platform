defmodule PlatformPhx.RuntimeRegistry.RuntimeProfile do
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

  schema "runtime_profiles" do
    field :name, :string
    field :runner_kind, :string
    field :execution_surface, :string
    field :billing_mode, :string, default: "user_local"
    field :status, :string, default: "active"
    field :visibility, :string, default: "operator"
    field :provider_runtime_id, :string
    field :observed_memory_mb, :integer
    field :observed_storage_bytes, :integer
    field :observed_capacity_at, :utc_datetime
    field :rate_limit_upgrade_url, :string
    field :config, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :platform_agent, PlatformPhx.AgentPlatform.Agent

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :company_id,
      :platform_agent_id,
      :name,
      :runner_kind,
      :execution_surface,
      :billing_mode,
      :status,
      :visibility,
      :provider_runtime_id,
      :observed_memory_mb,
      :observed_storage_bytes,
      :observed_capacity_at,
      :rate_limit_upgrade_url,
      :config,
      :metadata
    ])
    |> validate_required([
      :company_id,
      :name,
      :runner_kind,
      :execution_surface,
      :billing_mode,
      :status,
      :visibility
    ])
    |> validate_inclusion(:runner_kind, RwrEnums.runner_kinds())
    |> validate_inclusion(:execution_surface, RwrEnums.execution_surfaces())
    |> validate_inclusion(:billing_mode, RwrEnums.billing_modes())
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:status, ["active", "paused", "retired"])
    |> validate_number(:observed_memory_mb, greater_than_or_equal_to: 0)
    |> validate_number(:observed_storage_bytes, greater_than_or_equal_to: 0)
    |> validate_current_execution_shape()
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:platform_agent_id)
    |> unique_constraint([:company_id, :name])
  end

  defp validate_current_execution_shape(changeset) do
    changeset
    |> validate_openclaw_local_only()
    |> validate_codex_hosted_only()
  end

  defp validate_openclaw_local_only(changeset) do
    if get_field(changeset, :runner_kind) in @openclaw_runner_kinds do
      changeset
      |> require_field_value(:execution_surface, "local_bridge")
      |> require_field_value(:billing_mode, "user_local")
    else
      changeset
    end
  end

  defp validate_codex_hosted_only(changeset) do
    if get_field(changeset, :runner_kind) in @codex_runner_kinds do
      changeset
      |> require_field_value(:execution_surface, "hosted_sprite")
      |> require_field_value(:billing_mode, "platform_hosted")
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
