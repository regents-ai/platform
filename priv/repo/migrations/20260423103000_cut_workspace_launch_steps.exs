defmodule PlatformPhx.Repo.Migrations.CutWorkspaceLaunchSteps do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE platform_agent_formations
    SET current_step = 'bootstrap_workspace'
    WHERE current_step IN ('create_company', 'create_hermes')
    """)

    execute("""
    UPDATE platform_agent_formations
    SET last_error_step = 'bootstrap_workspace'
    WHERE last_error_step IN ('create_company', 'create_hermes')
    """)

    execute("""
    UPDATE platform_agent_formation_events
    SET step = 'bootstrap_workspace'
    WHERE step IN ('create_company', 'create_hermes')
    """)
  end

  def down do
    :ok
  end
end
