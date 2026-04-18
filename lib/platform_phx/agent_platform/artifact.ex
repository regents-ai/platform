defmodule PlatformPhx.AgentPlatform.Artifact do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_agent_artifacts" do
    field :title, :string
    field :summary, :string
    field :url, :string
    field :visibility, :string
    field :published_at, :utc_datetime

    belongs_to :agent, PlatformPhx.AgentPlatform.Agent
    belongs_to :job, PlatformPhx.AgentPlatform.Job

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:agent_id, :job_id, :title, :summary, :url, :visibility, :published_at])
    |> validate_required([:agent_id, :title, :summary, :visibility])
    |> validate_inclusion(:visibility, ["public", "private"])
    |> validate_change(:url, fn :url, url ->
      if public_url?(url), do: [], else: [url: "must be an http or https URL"]
    end)
  end

  def public_url?(nil), do: true
  def public_url?(""), do: true

  def public_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        true

      _other ->
        false
    end
  end

  def public_url?(_url), do: false
end
