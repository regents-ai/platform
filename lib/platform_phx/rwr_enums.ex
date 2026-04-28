defmodule PlatformPhx.RwrEnums do
  @moduledoc false

  @agent_kinds ["hermes", "openclaw", "codex", "custom", "human_operator", "regent_bridge"]
  @worker_roles ["manager", "executor", "hybrid"]
  @execution_surfaces ["hosted_sprite", "local_bridge", "external_webhook"]
  @runner_kinds [
    "hermes_local_manager",
    "hermes_hosted_manager",
    "openclaw_local_manager",
    "codex_exec",
    "codex_app_server",
    "openclaw_local_executor",
    "openclaw_code_agent_local",
    "fake",
    "custom_worker"
  ]
  @billing_modes ["platform_hosted", "user_local", "external_self_reported"]
  @trust_scopes ["platform_hosted", "local_user_controlled", "external_user_controlled"]
  @reported_usage_policies ["platform_metered", "self_reported", "external_reported"]
  @relationship_kinds ["manager_of", "preferred_executor", "can_delegate_to", "reports_to"]
  @relationship_statuses ["active", "paused", "revoked"]
  @visibility_values ["operator", "company", "public"]

  def agent_kinds, do: @agent_kinds
  def worker_roles, do: @worker_roles
  def execution_surfaces, do: @execution_surfaces
  def runner_kinds, do: @runner_kinds
  def billing_modes, do: @billing_modes
  def trust_scopes, do: @trust_scopes
  def reported_usage_policies, do: @reported_usage_policies
  def relationship_kinds, do: @relationship_kinds
  def relationship_statuses, do: @relationship_statuses
  def visibility_values, do: @visibility_values
end
