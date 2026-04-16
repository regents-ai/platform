defmodule PlatformPhx.SpriteRunnerFake do
  @moduledoc false

  def run(agent, _formation) do
    {:ok,
     %{
       "sprite_url" => "https://#{agent.slug}.sprites.dev",
       "paperclip_url" => "https://#{agent.slug}.sprites.dev:3100",
       "paperclip_company_id" => "#{agent.slug}-company",
       "paperclip_agent_id" => "#{agent.slug}-hermes",
       "workspace_path" => "/app/company",
       "workspace_seed_version" => "company-workspace-v1",
       "hermes_command" => "/app/bin/hermes-company",
       "prompt_template_version" => "company-workspace-prompt-v1",
       "checkpoint_ref" => "#{agent.slug}-checkpoint",
       "log_path" => "/tmp/#{agent.slug}-formation.log"
     }}
  end
end
