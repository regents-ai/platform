defmodule PlatformPhx.Agentbook.Link do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.Accounts.HumanUser

  schema "platform_world_agent_links" do
    field :wallet_address, :string
    field :chain_id, :integer
    field :registry_address, :string
    field :token_id, :string
    field :world_human_id, :string
    field :source, :string
    field :first_verified_at, :utc_datetime
    field :last_verified_at, :utc_datetime

    belongs_to :platform_human_user, HumanUser

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :wallet_address,
      :chain_id,
      :registry_address,
      :token_id,
      :world_human_id,
      :platform_human_user_id,
      :source,
      :first_verified_at,
      :last_verified_at
    ])
    |> validate_required([
      :wallet_address,
      :chain_id,
      :registry_address,
      :token_id,
      :world_human_id,
      :source,
      :first_verified_at,
      :last_verified_at
    ])
    |> unique_constraint([:wallet_address, :chain_id, :registry_address, :token_id])
  end
end
