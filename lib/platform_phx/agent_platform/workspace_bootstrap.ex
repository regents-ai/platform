defmodule PlatformPhx.AgentPlatform.WorkspaceBootstrap do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.TemplateCatalog
  alias PlatformPhx.RuntimeConfig

  @bootstrap_version "agent-formation-v1"
  @workspace_seed_version "company-workspace-v1"
  @workspace_path "/app/company"
  @hermes_command "/app/bin/hermes-company"
  @prompt_template_version "company-workspace-prompt-v1"
  @hermes_agent_ref "main"
  @workspace_repo "https://github.com/outsourc-e/hermes-workspace.git"
  @workspace_ref "main"

  def bootstrap_version, do: @bootstrap_version
  def workspace_seed_version, do: @workspace_seed_version
  def workspace_path, do: @workspace_path
  def hermes_command, do: @hermes_command
  def prompt_template_version, do: @prompt_template_version
  def hermes_agent_ref, do: @hermes_agent_ref
  def workspace_repo, do: @workspace_repo
  def workspace_ref, do: @workspace_ref

  def bundle_dir do
    Application.app_dir(:platform_phx, "priv/agent_formation")
  end

  def script_path do
    Path.join([bundle_dir(), "sprite", "bootstrap_sprite.sh"])
  end

  def build_env(%Agent{} = agent, %FormationRun{} = formation) do
    template = TemplateCatalog.get(agent.template_key)

    billing_account =
      agent.owner_human && PlatformPhx.AgentPlatform.get_billing_account(agent.owner_human)

    %{
      "FORMATION_SLUG" => agent.slug,
      "FORMATION_SPRITE_NAME" => agent.sprite_name || "#{agent.slug}-sprite",
      "FORMATION_PUBLIC_HOSTNAME" => "#{agent.slug}.regents.sh",
      "FORMATION_SPRITE_HOSTNAME" => "#{agent.slug}.sprites.dev",
      "FORMATION_ALLOWED_HOSTS" => "#{agent.slug}.sprites.dev,#{agent.slug}.regents.sh",
      "FORMATION_WORKSPACE_PORT" => Integer.to_string(agent.workspace_http_port || 3000),
      "FORMATION_HERMES_MODEL" => agent.hermes_model || "glm-5.1",
      "FORMATION_HERMES_ADAPTER_TYPE" => agent.hermes_adapter_type || "stock",
      "FORMATION_HERMES_PERSIST_SESSION" => to_string(agent.hermes_persist_session != false),
      "FORMATION_HERMES_TOOLSETS" => Jason.encode!(agent.hermes_toolsets || []),
      "FORMATION_HERMES_RUNTIME_PLUGINS" => Jason.encode!(agent.hermes_runtime_plugins || []),
      "FORMATION_HERMES_SHARED_SKILLS" => Jason.encode!(agent.hermes_shared_skills || []),
      "FORMATION_HERMES_COMMAND" => @hermes_command,
      "FORMATION_HERMES_AGENT_REF" => @hermes_agent_ref,
      "FORMATION_HERMES_PROMPT_TEMPLATE_VERSION" => @prompt_template_version,
      "FORMATION_HERMES_PROMPT_TEMPLATE_JSON" => Jason.encode!(hermes_prompt_template()),
      "FORMATION_WORKSPACE_REPO" => @workspace_repo,
      "FORMATION_WORKSPACE_REF" => @workspace_ref,
      "FORMATION_WORKSPACE_PATH" => @workspace_path,
      "FORMATION_WORKSPACE_SEED_VERSION" => @workspace_seed_version,
      "FORMATION_TEMPLATE_KEY" => agent.template_key || "",
      "FORMATION_TEMPLATE_PUBLIC_NAME" => (template && template.public_name) || "",
      "FORMATION_TEMPLATE_SUMMARY" => agent.public_summary || "",
      "FORMATION_TEMPLATE_COMPANY_PURPOSE" =>
        template_runtime_default(template, :company_purpose),
      "FORMATION_TEMPLATE_WORKER_ROLE" => template_runtime_default(template, :hermes_worker_role),
      "FORMATION_TEMPLATE_SERVICES" => Jason.encode!((template && template.services) || []),
      "FORMATION_TEMPLATE_CONNECTION_DEFAULTS" =>
        Jason.encode!((template && template.connection_defaults) || []),
      "FORMATION_TEMPLATE_RECOMMENDED_NETWORK_DOMAINS" =>
        Jason.encode!(template_runtime_default(template, :recommended_network_domains) || []),
      "FORMATION_TEMPLATE_CHECKPOINT_MOMENTS" =>
        Jason.encode!(template_runtime_default(template, :checkpoint_moments) || []),
      "FORMATION_STRIPE_CUSTOMER_ID" =>
        (billing_account && billing_account.stripe_customer_id) || "",
      "FORMATION_STRIPE_SUBSCRIPTION_ID" =>
        (billing_account && billing_account.stripe_pricing_plan_subscription_id) || "",
      "FORMATION_STRIPE_AI_GATEWAY_BASE_URL" => "https://llm.stripe.com",
      "FORMATION_BUNDLE_DIR" => bundle_dir(),
      "FORMATION_LOG_PATH" => formation.sprite_command_log_path || "",
      "SPRITE_CLI_PATH" => RuntimeConfig.sprite_cli_path(),
      "WORKSPACE_HTTP_PORT" => RuntimeConfig.workspace_http_port()
    }
  end

  defp template_runtime_default(nil, _key), do: nil

  defp template_runtime_default(template, key) do
    template
    |> Map.get(:runtime_defaults, %{})
    |> Map.get(key)
  end

  defp hermes_prompt_template do
    """
    You are {{agentName}}, the main worker for {{companyName}}.

    Start every run by reading /app/company/HOME.md and /app/company/AGENTS.md.
    Use /app/company/LOG.md for durable chronology.
    Use /app/company/BACKLOG.md for one-line queued work.
    Use /app/company/DECISIONS.md for settled choices.
    Keep /app/company/NOTES/ and /app/company/RUNBOOKS/ lightweight unless the work clearly deserves a durable home.

    {{#taskId}}
    Task {{taskId}}: {{taskTitle}}

    {{taskBody}}
    {{/taskId}}
    {{#noTask}}
    No task is assigned right now. Review the company workspace before taking action.
    {{/noTask}}
    """
    |> String.trim()
  end
end
