defmodule PlatformPhx.AgentPlatform.Agent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.AgentPlatform.Artifact
  alias PlatformPhx.AgentPlatform.BillingLedgerEntry
  alias PlatformPhx.AgentPlatform.Company
  alias PlatformPhx.AgentPlatform.Connection
  alias PlatformPhx.AgentPlatform.CreditLedger
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.Job
  alias PlatformPhx.AgentPlatform.LlmUsageEvent
  alias PlatformPhx.AgentPlatform.Service
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.AgentPlatform.Subdomain

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agents" do
    field :template_key, :string
    field :name, :string
    field :slug, :string
    field :claimed_label, :string
    field :basename_fqdn, :string
    field :ens_fqdn, :string
    field :status, :string
    field :public_summary, :string
    field :hero_statement, :string
    field :sprite_name, :string
    field :sprite_url, :string
    field :sprite_service_name, :string
    field :sprite_checkpoint_ref, :string
    field :sprite_created_at, :utc_datetime
    field :workspace_url, :string
    field :workspace_http_port, :integer
    field :hermes_adapter_type, :string
    field :hermes_model, :string
    field :hermes_persist_session, :boolean, default: true
    field :hermes_toolsets, {:array, :string}, default: []
    field :hermes_runtime_plugins, {:array, :string}, default: []
    field :hermes_shared_skills, {:array, :string}, default: []
    field :runtime_status, :string, default: "queued"
    field :checkpoint_status, :string, default: "pending"
    field :runtime_last_checked_at, :utc_datetime
    field :last_formation_error, :string
    field :stripe_llm_billing_status, :string, default: "not_connected"
    field :stripe_customer_id, :string
    field :stripe_pricing_plan_subscription_id, :string
    field :sprite_free_until, :utc_datetime
    field :sprite_credit_balance_usd_cents, :integer, default: 0
    field :sprite_metering_status, :string, default: "trialing"
    field :wallet_address, :string
    field :published_at, :utc_datetime
    field :desired_runtime_state, :string, default: "active"
    field :observed_runtime_state, :string, default: "unknown"

    belongs_to :owner_human, PlatformPhx.Accounts.HumanUser
    belongs_to :company, Company
    has_one :subdomain, Subdomain
    has_many :services, Service
    has_many :jobs, Job
    has_many :artifacts, Artifact
    has_many :connections, Connection
    has_one :formation_run, FormationRun
    has_many :credit_ledger_entries, CreditLedger
    has_many :llm_usage_events, LlmUsageEvent
    has_many :billing_ledger_entries, BillingLedgerEntry
    has_many :sprite_usage_records, SpriteUsageRecord

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :owner_human_id,
      :company_id,
      :template_key,
      :name,
      :slug,
      :claimed_label,
      :basename_fqdn,
      :ens_fqdn,
      :status,
      :public_summary,
      :hero_statement,
      :sprite_name,
      :sprite_url,
      :sprite_service_name,
      :sprite_checkpoint_ref,
      :sprite_created_at,
      :workspace_url,
      :workspace_http_port,
      :hermes_adapter_type,
      :hermes_model,
      :hermes_persist_session,
      :hermes_toolsets,
      :hermes_runtime_plugins,
      :hermes_shared_skills,
      :runtime_status,
      :checkpoint_status,
      :runtime_last_checked_at,
      :last_formation_error,
      :stripe_llm_billing_status,
      :stripe_customer_id,
      :stripe_pricing_plan_subscription_id,
      :sprite_free_until,
      :sprite_credit_balance_usd_cents,
      :sprite_metering_status,
      :wallet_address,
      :published_at,
      :desired_runtime_state,
      :observed_runtime_state
    ])
    |> validate_required([
      :template_key,
      :name,
      :slug,
      :claimed_label,
      :basename_fqdn,
      :public_summary
    ])
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_length(:name, max: 120)
    |> validate_length(:template_key, max: 80)
    |> validate_inclusion(:status, ["forming", "published", "failed"])
    |> validate_inclusion(:runtime_status, [
      "queued",
      "forming",
      "ready",
      "failed",
      "paused_for_credits",
      "paused"
    ])
    |> validate_inclusion(:checkpoint_status, ["pending", "ready", "failed"])
    |> validate_inclusion(:stripe_llm_billing_status, [
      "not_connected",
      "checkout_open",
      "active",
      "past_due"
    ])
    |> validate_inclusion(:sprite_metering_status, ["trialing", "paid", "paused"])
    |> validate_inclusion(:desired_runtime_state, ["active", "paused"])
    |> validate_inclusion(:observed_runtime_state, ["unknown", "active", "paused"])
    |> put_company_for_insert()
    |> foreign_key_constraint(:company_id)
    |> unique_constraint(:slug)
    |> unique_constraint(:claimed_label)
  end

  defp put_company_for_insert(changeset) do
    if changeset.valid? and is_nil(changeset.data.id) and
         is_nil(get_field(changeset, :company_id)) do
      prepare_changes(changeset, fn changeset ->
        case changeset.repo.insert(Company.changeset(%Company{}, company_attrs(changeset))) do
          {:ok, company} ->
            put_change(changeset, :company_id, company.id)

          {:error, _changeset} ->
            add_error(changeset, :company_id, "could not be created")
        end
      end)
    else
      changeset
    end
  end

  defp company_attrs(changeset) do
    %{
      owner_human_id: get_field(changeset, :owner_human_id),
      name: get_field(changeset, :name),
      slug: get_field(changeset, :slug),
      claimed_label: get_field(changeset, :claimed_label),
      status: get_field(changeset, :status) || "forming",
      public_summary: get_field(changeset, :public_summary),
      hero_statement: get_field(changeset, :hero_statement),
      metadata: %{}
    }
  end
end
