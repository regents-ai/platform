defmodule PlatformPhx.AgentPlatform.BillingLedgerEntry do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "platform_billing_ledger_entries" do
    field :entry_type, :string
    field :amount_usd_cents, :integer
    field :description, :string
    field :source_ref, :string
    field :effective_at, :utc_datetime

    belongs_to :billing_account, PlatformPhx.AgentPlatform.BillingAccount
    belongs_to :agent, PlatformPhx.AgentPlatform.Agent

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :billing_account_id,
      :agent_id,
      :entry_type,
      :amount_usd_cents,
      :description,
      :source_ref,
      :effective_at
    ])
    |> validate_required([:billing_account_id, :entry_type, :amount_usd_cents, :effective_at])
    |> validate_inclusion(:entry_type, [
      "topup",
      "runtime_debit",
      "trial_grant",
      "welcome_credit",
      "manual_adjustment"
    ])
    |> unique_constraint(:source_ref)
  end
end
