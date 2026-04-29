defmodule PlatformPhx.Workflows.Discovery do
  @moduledoc false

  alias PlatformPhx.Workflows.Parser

  @primary_file "REGENT_WORKFLOW.md"
  @secondary_file "WORKFLOW.md"
  @workflow_files [@primary_file, @secondary_file]

  def primary_file, do: @primary_file
  def workflow_files, do: @workflow_files

  def load(workspace_path) when is_binary(workspace_path) do
    workspace_path
    |> candidates()
    |> load_first_existing()
  end

  def load_from_reader(workspace_path, reader)
      when is_binary(workspace_path) and is_function(reader, 1) do
    workspace_path
    |> candidates()
    |> load_first_readable(reader)
  end

  def parse_loaded(source, path, content) when is_binary(content) do
    with {:ok, workflow} <- Parser.parse(content) do
      {:ok, workflow |> Map.put(:source, source) |> Map.put(:path, path)}
    end
  end

  defp candidates(workspace_path) do
    Enum.map(@workflow_files, fn file ->
      {file, Path.join(workspace_path, file)}
    end)
  end

  defp load_first_existing(candidates) do
    candidates
    |> Enum.reduce_while(nil, fn {file, path}, nil ->
      case File.read(path) do
        {:ok, content} -> {:halt, parse_loaded(file, path, content)}
        {:error, :enoent} -> {:cont, nil}
        {:error, :enotdir} -> {:cont, nil}
        {:error, reason} -> {:halt, {:error, {:workflow_unreadable, path, reason}}}
      end
    end)
    |> case do
      nil -> workflow_not_found(candidates)
      result -> result
    end
  end

  defp load_first_readable(candidates, reader) do
    candidates
    |> Enum.reduce_while(nil, fn {file, path}, nil ->
      case reader.(path) do
        {:ok, content} when is_binary(content) -> {:halt, parse_loaded(file, path, content)}
        {:error, :missing_workflow} -> {:cont, nil}
        {:error, :enoent} -> {:cont, nil}
        {:error, :enotdir} -> {:cont, nil}
        {:error, reason} -> {:halt, {:error, {:workflow_unreadable, path, reason}}}
      end
    end)
    |> case do
      nil -> workflow_not_found(candidates)
      result -> result
    end
  end

  defp workflow_not_found(candidates) do
    paths = Enum.map(candidates, fn {_file, path} -> path end)
    {:error, {:workflow_not_found, paths}}
  end
end
