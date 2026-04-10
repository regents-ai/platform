defmodule PlatformPhx.AgentPlatform.PaperclipBootstrap do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.RuntimeConfig

  @bootstrap_version "agent-formation-v1"

  def bootstrap_version, do: @bootstrap_version

  def bundle_dir do
    Application.app_dir(:platform_phx, "priv/agent_formation")
  end

  def script_path do
    Path.join([bundle_dir(), "sprite", "bootstrap_sprite.sh"])
  end

  def build_env(%Agent{} = agent, %FormationRun{} = formation) do
    %{
      "FORMATION_SLUG" => agent.slug,
      "FORMATION_SPRITE_NAME" => agent.sprite_name || "#{agent.slug}-sprite",
      "FORMATION_PUBLIC_HOSTNAME" => "#{agent.slug}.regents.sh",
      "FORMATION_SPRITE_HOSTNAME" => "#{agent.slug}.sprites.dev",
      "FORMATION_ALLOWED_HOSTNAME" => "#{agent.slug}.sprites.dev",
      "FORMATION_PAPERCLIP_PORT" => Integer.to_string(agent.paperclip_http_port || 3100),
      "FORMATION_PAPERCLIP_MODE" => agent.paperclip_deployment_mode || "authenticated",
      "FORMATION_HERMES_MODEL" => agent.hermes_model || "glm-5.1",
      "FORMATION_HERMES_ADAPTER_TYPE" => agent.hermes_adapter_type || "hermes_local",
      "FORMATION_HERMES_PERSIST_SESSION" => to_string(agent.hermes_persist_session != false),
      "FORMATION_HERMES_TOOLSETS" => Jason.encode!(agent.hermes_toolsets || []),
      "FORMATION_HERMES_RUNTIME_PLUGINS" => Jason.encode!(agent.hermes_runtime_plugins || []),
      "FORMATION_HERMES_SHARED_SKILLS" => Jason.encode!(agent.hermes_shared_skills || []),
      "FORMATION_STRIPE_CUSTOMER_ID" => agent.stripe_customer_id || "",
      "FORMATION_STRIPE_SUBSCRIPTION_ID" => agent.stripe_pricing_plan_subscription_id || "",
      "FORMATION_BUNDLE_DIR" => bundle_dir(),
      "FORMATION_LOG_PATH" => formation.sprite_command_log_path || "",
      "SPRITE_CLI_PATH" => RuntimeConfig.sprite_cli_path(),
      "PAPERCLIP_HTTP_PORT" => RuntimeConfig.paperclip_http_port()
    }
  end
end
