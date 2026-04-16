defmodule PlatformPhx.Repo.Migrations.RelaxOperatorReportIdentityColumns do
  use Ecto.Migration

  def change do
    alter table(:agent_bug_reports) do
      modify :reporter_wallet_address, :string, null: true
      modify :reporter_chain_id, :integer, null: true
      modify :reporter_registry_address, :string, null: true
      modify :reporter_token_id, :string, null: true
    end

    alter table(:agent_security_reports) do
      modify :reporter_wallet_address, :string, null: true
      modify :reporter_chain_id, :integer, null: true
      modify :reporter_registry_address, :string, null: true
      modify :reporter_token_id, :string, null: true
    end
  end
end
