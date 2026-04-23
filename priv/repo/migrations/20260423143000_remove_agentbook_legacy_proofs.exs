defmodule PlatformPhx.Repo.Migrations.RemoveAgentbookLegacyProofs do
  use Ecto.Migration

  def up do
    alter table(:platform_agentbook_sessions) do
      remove :allow_legacy_proofs
    end
  end
end
