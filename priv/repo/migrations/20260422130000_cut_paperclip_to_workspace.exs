defmodule PlatformPhx.Repo.Migrations.CutPaperclipToWorkspace do
  use Ecto.Migration

  def up do
    rename table(:platform_agents), :paperclip_url, to: :workspace_url
    rename table(:platform_agents), :paperclip_http_port, to: :workspace_http_port

    alter table(:platform_agents) do
      remove :paperclip_deployment_mode
      remove :paperclip_company_id
      remove :paperclip_agent_id
    end

    execute("""
    UPDATE platform_agents
    SET sprite_service_name = 'hermes-workspace',
        workspace_http_port = 3000,
        workspace_url = REGEXP_REPLACE(COALESCE(workspace_url, ''), ':3100$', ''),
        hermes_adapter_type = CASE
          WHEN hermes_adapter_type IS NULL OR hermes_adapter_type = '' OR hermes_adapter_type = 'hermes_local'
            THEN 'stock'
          ELSE hermes_adapter_type
        END
    """)

    execute("""
    UPDATE platform_agent_formations
    SET current_step = 'bootstrap_workspace'
    WHERE current_step = 'bootstrap_paperclip'
    """)

    execute("""
    UPDATE platform_agent_formation_events
    SET step = 'bootstrap_workspace'
    WHERE step = 'bootstrap_paperclip'
    """)
  end

  def down do
    alter table(:platform_agents) do
      add :paperclip_deployment_mode, :string
      add :paperclip_company_id, :string
      add :paperclip_agent_id, :string
    end

    execute("""
    UPDATE platform_agents
    SET sprite_service_name = 'paperclip',
        workspace_http_port = 3100,
        workspace_url = CASE
          WHEN workspace_url IS NULL OR workspace_url = '' THEN workspace_url
          WHEN workspace_url LIKE '%:3100' THEN workspace_url
          ELSE workspace_url || ':3100'
        END,
        hermes_adapter_type = CASE
          WHEN hermes_adapter_type = 'stock' THEN 'hermes_local'
          ELSE hermes_adapter_type
        END,
        paperclip_deployment_mode = 'authenticated',
        paperclip_company_id = slug || '-company',
        paperclip_agent_id = slug || '-hermes'
    """)

    rename table(:platform_agents), :workspace_http_port, to: :paperclip_http_port
    rename table(:platform_agents), :workspace_url, to: :paperclip_url

    execute("""
    UPDATE platform_agent_formations
    SET current_step = 'bootstrap_paperclip'
    WHERE current_step = 'bootstrap_workspace'
    """)

    execute("""
    UPDATE platform_agent_formation_events
    SET step = 'bootstrap_paperclip'
    WHERE step = 'bootstrap_workspace'
    """)
  end
end
