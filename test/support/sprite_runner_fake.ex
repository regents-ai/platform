defmodule PlatformPhx.SpriteRunnerFake do
  @moduledoc false

  def run(agent, _formation) do
    {:ok,
     %{
       "sprite_url" => "https://#{agent.slug}.sprites.dev",
       "workspace_url" => "https://#{agent.slug}.sprites.dev",
       "workspace_path" => "/app/company",
       "workspace_seed_version" => "company-workspace-v1",
       "workspace_repo" => "https://github.com/outsourc-e/hermes-workspace.git",
       "workspace_ref" => "60ee8ea2d0dd9092258246388134125845fbfe2b",
       "hermes_command" => "/app/bin/hermes-company",
       "hermes_agent_ref" => "v2026.4.16",
       "prompt_template_version" => "company-workspace-prompt-v1",
       "checkpoint_ref" => "#{agent.slug}-checkpoint",
       "log_path" => "/tmp/#{agent.slug}-formation.log"
     }}
  end
end
