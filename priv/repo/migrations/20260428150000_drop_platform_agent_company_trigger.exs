defmodule PlatformPhx.Repo.Migrations.DropPlatformAgentCompanyTrigger do
  use Ecto.Migration

  def up do
    execute("DROP TRIGGER IF EXISTS platform_agents_company_before_insert ON platform_agents")
    execute("DROP FUNCTION IF EXISTS platform_create_company_for_agent()")
  end

  def down do
    raise "platform agent company trigger was removed by hard cutover"
  end
end
