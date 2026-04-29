defmodule PlatformPhx.Workflows.Renderer do
  @moduledoc false

  @placeholder ~r/{{\s*([a-zA-Z0-9_.]+)\s*}}/

  def render_prompt(workflow, context) when is_map(workflow) and is_map(context) do
    template = Map.fetch!(workflow, :prompt_template)
    render_template(template, context)
  end

  def render_template(template, context) when is_binary(template) and is_map(context) do
    @placeholder
    |> Regex.scan(template)
    |> Enum.reduce_while({:ok, template}, fn [match, path], {:ok, rendered} ->
      case fetch_in_path(context, String.split(path, ".")) do
        {:ok, value} ->
          {:cont, {:ok, String.replace(rendered, match, stringify(value), global: false)}}

        {:error, _reason} ->
          {:halt, {:error, {:missing_workflow_template_value, path}}}
      end
    end)
  end

  def manager_prompt(workflow, context) do
    with {:ok, prompt} <- render_prompt(workflow, context) do
      {:ok, compose_prompt("Regent Manager Workflow", workflow, prompt, context)}
    end
  end

  def executor_prompt(workflow, context) do
    with {:ok, prompt} <- render_prompt(workflow, context) do
      {:ok, compose_prompt("Regent Executor Workflow", workflow, prompt, context)}
    end
  end

  defp compose_prompt(title, workflow, prompt, context) do
    workflow_config = Map.get(workflow, :config, %{})

    [
      "# Regent Workflow",
      "",
      "## Prompt Role",
      "",
      title,
      "",
      "## Workflow",
      "",
      prompt,
      "",
      "## Workflow Config",
      "",
      encode(workflow_config),
      "",
      "## Runner Policy",
      "",
      encode(merged_policy(workflow_config, "runner", context["runner_policy"])),
      "",
      "## Delegation Policy",
      "",
      encode(merged_policy(workflow_config, "delegation", context["delegation_policy"])),
      "",
      "## Techtree Publish Policy",
      "",
      encode(merged_policy(workflow_config, "techtree", context["techtree_publish_policy"])),
      "",
      "## Protected Actions",
      "",
      encode(context["protected_actions"]),
      "",
      "## Visibility",
      "",
      encode(context["visibility"]),
      "",
      "## Budget Notes",
      "",
      encode(context["budget_notes"]),
      "",
      "## Artifact Expectations",
      "",
      encode(context["artifact_expectations"]),
      "",
      "## Run Context",
      "",
      encode(context),
      "",
      "## Workflow Source",
      "",
      encode(%{source: Map.get(workflow, :source), path: Map.get(workflow, :path)})
    ]
    |> Enum.join("\n")
  end

  defp merged_policy(workflow_config, section, context_policy) do
    workflow_policy =
      case Map.get(workflow_config, section) do
        value when is_map(value) -> value
        _value -> %{}
      end

    context_policy =
      case context_policy do
        value when is_map(value) -> value
        nil -> %{}
        value -> %{"value" => value}
      end

    Map.merge(workflow_policy, context_policy)
  end

  defp encode(value), do: Jason.encode!(value, pretty: true)

  defp fetch_in_path(context, path) do
    path
    |> Enum.reduce_while({:ok, context}, fn key, {:ok, current} ->
      case current do
        map when is_map(map) ->
          case Map.fetch(map, key) do
            {:ok, value} -> {:cont, {:ok, value}}
            :error -> {:halt, {:error, :missing}}
          end

        _value ->
          {:halt, {:error, :missing}}
      end
    end)
    |> case do
      {:ok, nil} -> {:error, :missing}
      result -> result
    end
  end

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_integer(value), do: Integer.to_string(value)
  defp stringify(value) when is_float(value), do: Float.to_string(value)
  defp stringify(value) when is_boolean(value), do: to_string(value)
  defp stringify(value), do: Jason.encode!(value)
end
