defmodule PlatformPhx.Repo.Migrations.AddRegentEnsClaimFields do
  use Ecto.Migration

  def change do
    alter table(:basenames_mints) do
      add :claim_status, :string, null: false, default: "reserved"
      add :upgrade_tx_hash, :string
      add :upgraded_at, :utc_datetime
      add :formation_agent_slug, :string
      add :attached_agent_slug, :string
    end

    alter table(:platform_agents) do
      modify :ens_fqdn, :string, null: true
    end

    create index(:basenames_mints, [:claim_status])

    create unique_index(:basenames_mints, [:formation_agent_slug],
             where: "formation_agent_slug IS NOT NULL"
           )

    create unique_index(:basenames_mints, [:attached_agent_slug],
             where: "attached_agent_slug IS NOT NULL"
           )
  end
end
