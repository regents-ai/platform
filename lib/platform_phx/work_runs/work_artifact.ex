defmodule PlatformPhx.WorkRuns.WorkArtifact do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.RwrEnums

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "work_artifacts" do
    field :kind, :string
    field :title, :string
    field :uri, :string
    field :digest, :string
    field :visibility, :string, default: "operator"
    field :attestation_level, :string, default: "local_self_reported"
    field :content_inline, :string
    field :metadata, :map, default: %{}

    belongs_to :company, PlatformPhx.AgentPlatform.Company
    belongs_to :work_item, PlatformPhx.Work.WorkItem
    belongs_to :run, PlatformPhx.WorkRuns.WorkRun

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :company_id,
      :work_item_id,
      :run_id,
      :kind,
      :title,
      :uri,
      :digest,
      :visibility,
      :attestation_level,
      :content_inline,
      :metadata
    ])
    |> validate_required([
      :company_id,
      :work_item_id,
      :run_id,
      :kind,
      :visibility,
      :attestation_level
    ])
    |> validate_inclusion(:visibility, RwrEnums.visibility_values())
    |> validate_inclusion(:attestation_level, [
      "local_self_reported",
      "platform_observed",
      "external_attested"
    ])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:work_item_id)
    |> foreign_key_constraint(:run_id)
  end
end
