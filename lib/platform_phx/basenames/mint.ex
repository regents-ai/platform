defmodule PlatformPhx.Basenames.Mint do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  @type t :: %__MODULE__{
          id: integer() | nil,
          parent_node: String.t() | nil,
          parent_name: String.t() | nil,
          label: String.t() | nil,
          fqdn: String.t() | nil,
          node: String.t() | nil,
          ens_fqdn: String.t() | nil,
          ens_node: String.t() | nil,
          owner_address: String.t() | nil,
          tx_hash: String.t() | nil,
          claim_status: String.t() | nil,
          upgrade_tx_hash: String.t() | nil,
          upgraded_at: DateTime.t() | nil,
          formation_agent_slug: String.t() | nil,
          attached_agent_slug: String.t() | nil,
          payment_tx_hash: String.t() | nil,
          payment_chain_id: integer() | nil,
          price_wei: integer() | nil,
          is_free: boolean() | nil,
          is_in_use: boolean() | nil,
          created_at: DateTime.t() | nil
        }

  schema "basenames_mints" do
    field :parent_node, :string
    field :parent_name, :string
    field :label, :string
    field :fqdn, :string
    field :node, :string
    field :ens_fqdn, :string
    field :ens_node, :string
    field :owner_address, :string
    field :tx_hash, :string
    field :claim_status, :string, default: "reserved"
    field :upgrade_tx_hash, :string
    field :upgraded_at, :utc_datetime
    field :formation_agent_slug, :string
    field :attached_agent_slug, :string
    field :payment_tx_hash, :string
    field :payment_chain_id, :integer
    field :price_wei, :integer
    field :is_free, :boolean
    field :is_in_use, :boolean

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @required_fields ~w(parent_node parent_name label fqdn node owner_address tx_hash is_free claim_status)a
  @optional_fields ~w(
    ens_fqdn
    ens_node
    upgrade_tx_hash
    upgraded_at
    formation_agent_slug
    attached_agent_slug
    payment_tx_hash
    payment_chain_id
    price_wei
    is_in_use
  )a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(mint, attrs) do
    mint
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:claim_status, [
      "reserved",
      "upgrade_pending",
      "onchain_live",
      "upgrade_failed"
    ])
    |> unique_constraint(:node, name: :basenames_mints_node_unique)
    |> unique_constraint(:payment_tx_hash, name: :basenames_mints_payment_tx_unique)
  end
end
