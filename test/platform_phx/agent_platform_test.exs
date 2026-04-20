defmodule PlatformPhx.AgentPlatformTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.AgentPlatform
  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.PaperclipBootstrap

  test "runtime payload fills workspace defaults for older formation runs" do
    agent = %Agent{
      owner_human_id: 1,
      runtime_status: "ready",
      paperclip_deployment_mode: "authenticated",
      paperclip_http_port: 3100,
      hermes_adapter_type: "hermes_local",
      hermes_model: "glm-5.1",
      hermes_persist_session: true,
      hermes_toolsets: [],
      hermes_runtime_plugins: [],
      hermes_shared_skills: [],
      formation_run: %FormationRun{metadata: %{}}
    }

    payload = AgentPlatform.runtime_payload_map(agent, %BillingAccount{})

    assert payload.paperclip.workspace_path == PaperclipBootstrap.workspace_path()

    assert payload.paperclip.workspace_seed_version ==
             PaperclipBootstrap.workspace_seed_version()

    assert payload.hermes.command == PaperclipBootstrap.hermes_command()

    assert payload.hermes.prompt_template_version ==
             PaperclipBootstrap.prompt_template_version()
  end
end
