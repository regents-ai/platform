defmodule PlatformPhx.Workflows do
  @moduledoc false

  alias PlatformPhx.Workflows.Context
  alias PlatformPhx.Workflows.Discovery
  alias PlatformPhx.Workflows.Parser
  alias PlatformPhx.Workflows.Renderer

  def workflow_file, do: Discovery.primary_file()
  def workflow_files, do: Discovery.workflow_files()

  def workflow_path(workspace_path) when is_binary(workspace_path) do
    Path.join(workspace_path, workflow_file())
  end

  def load(workspace_path) when is_binary(workspace_path), do: Discovery.load(workspace_path)
  def parse(content) when is_binary(content), do: Parser.parse(content)

  def prompt_context(run, workspace), do: Context.build(run, workspace)

  def render_prompt(workflow, context), do: Renderer.render_prompt(workflow, context)
  def render_template(template, context), do: Renderer.render_template(template, context)

  def symphony_prompt(workflow, context), do: Renderer.manager_prompt(workflow, context)
  def manager_prompt(workflow, context), do: Renderer.manager_prompt(workflow, context)
  def executor_prompt(workflow, context), do: Renderer.executor_prompt(workflow, context)
end
