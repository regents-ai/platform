defmodule PlatformPhx.Workflows.Parser do
  @moduledoc false

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
    |> Enum.reduce_while({:ok, %{}, nil, nil}, &parse_frontmatter_line/2)
    |> case do
      {:ok, config, _section_key, _list_key} -> {:ok, config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_frontmatter_line(line, {:ok, config, section_key, list_key}) do
    cond do
      String.starts_with?(line, "    - ") and is_binary(section_key) and is_binary(list_key) ->
        value = line |> String.replace_prefix("    - ", "") |> parse_scalar()

        case append_nested_list_value(config, section_key, list_key, value) do
          {:ok, config} -> {:cont, {:ok, config, section_key, list_key}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      String.starts_with?(line, "  - ") and is_binary(section_key) ->
        value = line |> String.replace_prefix("  - ", "") |> parse_scalar()

        case append_top_level_list_value(config, section_key, value) do
          {:ok, config} -> {:cont, {:ok, config, section_key, nil}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      Regex.match?(~r/^  [A-Za-z0-9_]+:\s*(.*)$/, line) and is_binary(section_key) ->
        [key, raw_value] =
          line
          |> String.trim_leading()
          |> String.split(":", parts: 2)

        raw_value = String.trim(raw_value)

        if raw_value == "" do
          config = put_nested(config, section_key, key, [])
          {:cont, {:ok, config, section_key, key}}
        else
          config = put_nested(config, section_key, key, parse_scalar(raw_value))
          {:cont, {:ok, config, section_key, nil}}
        end

      Regex.match?(~r/^[A-Za-z0-9_]+:\s*(.*)$/, line) ->
        [key, raw_value] = String.split(line, ":", parts: 2)
        raw_value = String.trim(raw_value)

        if raw_value == "" do
          {:cont, {:ok, Map.put(config, key, %{}), key, nil}}
        else
          {:cont, {:ok, Map.put(config, key, parse_scalar(raw_value)), nil, nil}}
        end

      true ->
        {:halt, {:error, {:invalid_regent_workflow_frontmatter, line}}}
    end
  end

  defp append_top_level_list_value(config, section_key, value) do
    case Map.get(config, section_key) do
      values when is_list(values) ->
        {:ok, Map.put(config, section_key, values ++ [value])}

      map when is_map(map) and map_size(map) == 0 ->
        {:ok, Map.put(config, section_key, [value])}

      _other ->
        {:error, {:invalid_regent_workflow_frontmatter, "  - #{value}"}}
    end
  end

  defp append_nested_list_value(config, section_key, list_key, value) do
    section = Map.get(config, section_key, %{})

    case Map.get(section, list_key) do
      values when is_list(values) ->
        {:ok, put_nested(config, section_key, list_key, values ++ [value])}

      _other ->
        {:error, {:invalid_regent_workflow_frontmatter, "    - #{value}"}}
    end
  end

  defp put_nested(config, section_key, key, value) do
    section =
      case Map.get(config, section_key) do
        section when is_map(section) -> section
        _other -> %{}
      end

    Map.put(config, section_key, Map.put(section, key, value))
  end

  defp parse_scalar(value) do
    value = String.trim(value)

    cond do
      value == "null" ->
        nil

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
end
