defmodule PlatformPhx.Repo.Migrations.AddWorldAgentbookTrust do
  use Ecto.Migration

  def change do
    alter table(:platform_human_users) do
      add :world_human_id, :string
      add :world_verified_at, :utc_datetime
    end

    create index(:platform_human_users, [:world_human_id])

    create table(:platform_world_agent_links) do
      add :wallet_address, :string, null: false
      add :chain_id, :integer, null: false
      add :registry_address, :string, null: false
      add :token_id, :string, null: false
      add :world_human_id, :string, null: false
      add :platform_human_user_id, references(:platform_human_users, on_delete: :nilify_all)
      add :source, :string, null: false
      add :first_verified_at, :utc_datetime, null: false
      add :last_verified_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:platform_world_agent_links, [
             :wallet_address,
             :chain_id,
             :registry_address,
             :token_id
           ])

    create index(:platform_world_agent_links, [:world_human_id])
    create index(:platform_world_agent_links, [:platform_human_user_id])

    create table(:platform_agentbook_sessions, primary_key: false) do
      add :session_id, :string, primary_key: true
      add :wallet_address, :string, null: false
      add :chain_id, :integer, null: false
      add :registry_address, :string, null: false
      add :token_id, :string, null: false
      add :network, :string, null: false
      add :source, :string, null: false
      add :contract_address, :string
      add :relay_url, :string
      add :nonce, :bigint
      add :approval_token_hash, :string, null: false
      add :app_id, :string
      add :action, :string
      add :rp_id, :string
      add :signal, :string
      add :rp_context, :map
      add :allow_legacy_proofs, :boolean, null: false, default: false
      add :connector_uri, :text
      add :deep_link_uri, :text
      add :proof_payload, :map
      add :tx_request, :map
      add :status, :string, null: false
      add :world_human_id, :string
      add :platform_human_user_id, references(:platform_human_users, on_delete: :nilify_all)
      add :error_text, :text
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:platform_agentbook_sessions, [:wallet_address, :status])
    create index(:platform_agentbook_sessions, [:platform_human_user_id])
    create index(:platform_agentbook_sessions, [:world_human_id])
  end
end
