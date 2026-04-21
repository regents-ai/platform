defmodule PlatformPhx.Repo.Migrations.AllowNullAgentEnsFqdn do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE platform_agents ALTER COLUMN ens_fqdn DROP NOT NULL")
  end

  def down do
    execute("ALTER TABLE platform_agents ALTER COLUMN ens_fqdn SET NOT NULL")
  end
end
