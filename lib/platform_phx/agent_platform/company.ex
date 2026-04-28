defmodule PlatformPhx.AgentPlatform.Company do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.AgentPlatform.Agent

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_companies" do
    field :name, :string
    field :slug, :string
    field :claimed_label, :string
    field :status, :string, default: "forming"
    field :public_summary, :string
    field :hero_statement, :string
    field :metadata, :map, default: %{}

    belongs_to :owner_human, PlatformPhx.Accounts.HumanUser
    has_many :agents, Agent

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(company, attrs) do
    company
    |> cast(attrs, [
      :owner_human_id,
      :name,
      :slug,
      :claimed_label,
      :status,
      :public_summary,
      :hero_statement,
      :metadata
    ])
    |> validate_required([
      :owner_human_id,
      :name,
      :slug,
      :claimed_label,
      :status,
      :public_summary
    ])
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_length(:name, max: 120)
    |> validate_inclusion(:status, ["forming", "published", "failed"])
    |> foreign_key_constraint(:owner_human_id)
    |> unique_constraint(:slug)
    |> unique_constraint(:claimed_label)
  end
end
