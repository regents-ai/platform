defmodule PlatformPhx.Agentbook.Session do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias PlatformPhx.Accounts.HumanUser

  @primary_key {:session_id, :string, autogenerate: false}

  schema "platform_agentbook_sessions" do
    field :wallet_address, :string
    field :chain_id, :integer
    field :registry_address, :string
    field :token_id, :string
    field :network, :string
    field :source, :string
    field :contract_address, :string
    field :relay_url, :string
    field :nonce, :integer
    field :approval_token_hash, :string
    field :app_id, :string
    field :action, :string
    field :rp_id, :string
    field :signal, :string
    field :rp_context, :map
    field :allow_legacy_proofs, :boolean, default: false
    field :connector_uri, :string
    field :deep_link_uri, :string
    field :status, :string
    field :world_human_id, :string
    field :error_text, :string
    field :expires_at, :utc_datetime_usec

    belongs_to :platform_human_user, HumanUser

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :wallet_address,
      :chain_id,
      :registry_address,
      :token_id,
      :network,
      :source,
      :contract_address,
      :relay_url,
      :nonce,
      :approval_token_hash,
      :app_id,
      :action,
      :rp_id,
      :signal,
      :rp_context,
      :allow_legacy_proofs,
      :connector_uri,
      :deep_link_uri,
      :status,
      :world_human_id,
      :platform_human_user_id,
      :error_text,
      :expires_at
    ])
    |> validate_required([
      :session_id,
      :wallet_address,
      :chain_id,
      :registry_address,
      :token_id,
      :network,
      :source,
      :approval_token_hash,
      :status,
      :expires_at
    ])
  end

  def update_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :connector_uri,
      :deep_link_uri,
      :status,
      :world_human_id,
      :platform_human_user_id,
      :error_text
    ])
  end
end
