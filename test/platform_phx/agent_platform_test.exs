defmodule PlatformPhx.AgentPlatformTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.WorkspaceBootstrap

  test "runtime payload fills workspace defaults for older formation runs" do
    agent = %Agent{
      owner_human_id: 1,
      runtime_status: "ready",
      workspace_http_port: 3000,
      hermes_adapter_type: "stock",
      hermes_model: "glm-5.1",
      hermes_persist_session: true,
      hermes_toolsets: [],
      hermes_runtime_plugins: [],
      hermes_shared_skills: [],
      formation_run: %FormationRun{metadata: %{}}
    }

    payload = AgentPlatform.runtime_payload_map(agent, %BillingAccount{})

    assert payload.workspace.workspace_path == WorkspaceBootstrap.workspace_path()

    assert payload.workspace.workspace_seed_version ==
             WorkspaceBootstrap.workspace_seed_version()

    assert payload.hermes.command == WorkspaceBootstrap.hermes_command()

    assert payload.hermes.prompt_template_version ==
             WorkspaceBootstrap.prompt_template_version()
  end
end
