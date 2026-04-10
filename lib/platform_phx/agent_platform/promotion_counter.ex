defmodule PlatformPhx.AgentPlatform.PromotionCounter do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "platform_promotion_counters" do
    field :promotion_key, :string
    field :next_rank, :integer, default: 1
    field :limit_count, :integer, default: 100

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(counter, attrs) do
    counter
    |> cast(attrs, [:promotion_key, :next_rank, :limit_count])
    |> validate_required([:promotion_key, :next_rank, :limit_count])
    |> validate_number(:next_rank, greater_than: 0)
    |> validate_number(:limit_count, greater_than: 0)
    |> unique_constraint(:promotion_key)
  end
end
