defmodule PlatformPhx.Accounts.HumanUser do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "platform_human_users" do
    field :privy_user_id, :string
    field :wallet_address, :string
    field :wallet_addresses, {:array, :string}, default: []
    field :xmtp_inbox_id, :string
    field :world_human_id, :string
    field :world_verified_at, :utc_datetime
    field :display_name, :string
    field :avatar, :map
    field :stripe_llm_billing_status, :string, default: "not_connected"
    field :stripe_customer_id, :string
    field :stripe_pricing_plan_subscription_id, :string

    has_one :billing_account, PlatformPhx.AgentPlatform.BillingAccount
    has_many :welcome_credit_grants, PlatformPhx.AgentPlatform.WelcomeCreditGrant

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(human, attrs) do
    human
    |> cast(attrs, [
      :privy_user_id,
      :wallet_address,
      :wallet_addresses,
      :xmtp_inbox_id,
      :world_human_id,
      :world_verified_at,
      :display_name,
      :avatar,
      :stripe_llm_billing_status,
      :stripe_customer_id,
      :stripe_pricing_plan_subscription_id
    ])
    |> validate_required([:privy_user_id])
    |> validate_length(:xmtp_inbox_id, max: 160)
    |> validate_length(:display_name, max: 80)
    |> validate_inclusion(:stripe_llm_billing_status, [
      "not_connected",
      "checkout_open",
      "active",
      "past_due"
    ])
    |> unique_constraint(:privy_user_id)
    |> unique_constraint(:world_human_id)
  end
end
