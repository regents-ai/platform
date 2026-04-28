defmodule PlatformPhx.Workflows do
  @moduledoc false

  @workflow_file "REGENT_WORKFLOW.md"
  @placeholder ~r/{{\s*([a-zA-Z0-9_.]+)\s*}}/

  def workflow_file, do: @workflow_file

  def workflow_path(workspace_path) when is_binary(workspace_path) do
    Path.join(workspace_path, @workflow_file)
  end

  def load(workspace_path) when is_binary(workspace_path) do
    path = workflow_path(workspace_path)

    case File.read(path) do
      {:ok, content} ->
        with {:ok, workflow} <- parse(content) do
          {:ok, Map.put(workflow, :path, path)}
        end

      {:error, reason} ->
        {:error, {:missing_regent_workflow, path, reason}}
    end
  end

  def parse(content) when is_binary(content) do
    with {:ok, frontmatter, body} <- split_frontmatter(content),
         {:ok, config} <- parse_frontmatter(frontmatter) do
      prompt_template = String.trim(body)

      {:ok,
       %{
         config: config,
         prompt_template: prompt_template,
         prompt: prompt_template
       }}
    end
  end

  def prompt_context(run, workspace) do
    work_item = Map.get(run, :work_item)
    runtime_profile = Map.get(run, :runtime_profile)

    %{
      "run" => %{
        "id" => value(run, :id),
        "runner_kind" => value(run, :runner_kind),
        "input" => value(run, :input) || %{},
        "metadata" => value(run, :metadata) || %{}
      },
      "work_item" => %{
        "id" => value(work_item, :id),
        "title" => value(work_item, :title),
        "body" => value(work_item, :body),
        "acceptance_criteria" => value(work_item, :acceptance_criteria) || []
      },
      "runtime" => %{
        "id" => value(runtime_profile, :id),
        "name" => value(runtime_profile, :name),
        "runner_kind" => value(runtime_profile, :runner_kind),
        "execution_surface" => value(runtime_profile, :execution_surface),
        "metadata" => value(runtime_profile, :metadata) || %{}
      },
      "workspace" => %{
        "path" => workspace.path,
        "prompt_path" => Map.get(workspace, :prompt_path)
      }
    }
  end

  def render_prompt(workflow, context) when is_map(workflow) and is_map(context) do
    template = Map.fetch!(workflow, :prompt_template)
    render_template(template, context)
  end

  def render_template(template, context) when is_binary(template) and is_map(context) do
    rendered =
      Regex.replace(@placeholder, template, fn _match, path ->
        context
        |> get_in_path(String.split(path, "."))
        |> stringify()
      end)

    {:ok, rendered}
  end

  def symphony_prompt(workflow, context) do
    with {:ok, prompt} <- render_prompt(workflow, context) do
      {:ok,
       [
         "# Regent Workflow",
         "",
         prompt,
         "",
         "## Run Context",
         "",
         Jason.encode!(context, pretty: true)
       ]
       |> Enum.join("\n")}
    end
  end

  defp split_frontmatter(content) do
    lines = String.split(content, ~r/\R/, trim: false)

    case lines do
      ["---" | tail] ->
        {frontmatter, rest} = Enum.split_while(tail, &(&1 != "---"))

        case rest do
          ["---" | body] -> {:ok, frontmatter, Enum.join(body, "\n")}
          _ -> {:error, :regent_workflow_frontmatter_not_closed}
        end

      _ ->
        {:ok, [], content}
    end
  end

  defp parse_frontmatter([]), do: {:ok, %{}}

  defp parse_frontmatter(lines) do
    lines
    |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
    |> Enum.reduce_while({:ok, %{}, nil}, &parse_frontmatter_line/2)
    |> case do
      {:ok, config, _current_list_key} -> {:ok, config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_frontmatter_line(line, {:ok, config, current_list_key}) do
    cond do
      String.starts_with?(line, "  - ") and is_binary(current_list_key) ->
        value = line |> String.replace_prefix("  - ", "") |> parse_scalar()
        existing = Map.get(config, current_list_key, [])
        {:cont, {:ok, Map.put(config, current_list_key, existing ++ [value]), current_list_key}}

      Regex.match?(~r/^[A-Za-z0-9_]+:\s*(.*)$/, line) ->
        [key, raw_value] = String.split(line, ":", parts: 2)
        raw_value = String.trim(raw_value)

        if raw_value == "" do
          {:cont, {:ok, Map.put(config, key, []), key}}
        else
          {:cont, {:ok, Map.put(config, key, parse_scalar(raw_value)), nil}}
        end

      true ->
        {:halt, {:error, {:invalid_regent_workflow_frontmatter, line}}}
    end
  end

  defp parse_scalar(value) do
    value = String.trim(value)

    cond do
      value in ["true", "false"] ->
        value == "true"

      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)

      String.starts_with?(value, "[") and String.ends_with?(value, "]") ->
        value
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> String.split(",", trim: true)
        |> Enum.map(&parse_scalar/1)

      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        value |> String.trim_leading("\"") |> String.trim_trailing("\"")

      true ->
        value
    end
  end

  defp get_in_path(context, path) do
    Enum.reduce_while(path, context, fn key, current ->
      case current do
        map when is_map(map) ->
          case Map.fetch(map, key) do
            {:ok, value} -> {:cont, value}
            :error -> {:halt, ""}
          end

        _value ->
          {:halt, ""}
      end
    end)
  end

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_integer(value), do: Integer.to_string(value)
  defp stringify(value) when is_float(value), do: Float.to_string(value)
  defp stringify(value) when is_boolean(value), do: to_string(value)
  defp stringify(nil), do: ""
  defp stringify(value), do: Jason.encode!(value)

  defp value(nil, _key), do: nil

  defp value(map, key) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp value(struct, key), do: Map.get(struct, key)
end
