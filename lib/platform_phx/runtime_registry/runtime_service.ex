defmodule PlatformPhx.RuntimeRegistry.RuntimeService do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "runtime_services" do
    field :name, :string
    field :service_kind, :string
    field :status, :string, default: "active"
    field :endpoint_url, :string
    field :provider_service_id, :string
    field :status_observed_at, :utc_datetime
    field :log_cursor, :string
    field :last_log_excerpt, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :runtime_profile, PlatformPhx.RuntimeRegistry.RuntimeProfile

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(service, attrs) do
    service
    |> cast(attrs, [
      :company_id,
      :runtime_profile_id,
      :name,
      :service_kind,
      :status,
      :endpoint_url,
      :provider_service_id,
      :status_observed_at,
      :log_cursor,
      :last_log_excerpt,
      :metadata
    ])
    |> validate_required([:company_id, :runtime_profile_id, :name, :service_kind, :status])
    |> validate_inclusion(:status, [
      "active",
      "paused",
      "retired",
      "unknown",
      "starting",
      "stopping",
      "failed"
    ])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:runtime_profile_id)
    |> unique_constraint([:runtime_profile_id, :name])
  end
end
