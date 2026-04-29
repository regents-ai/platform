defmodule PlatformPhx.Workflows.DiscoveryTest do
  use ExUnit.Case, async: true

  alias PlatformPhx.Workflows
  alias PlatformPhx.Workflows.Discovery

  test "loads REGENT_WORKFLOW.md before WORKFLOW.md" do
    workspace = workspace_path("primary")
    File.mkdir_p!(workspace)

    File.write!(Path.join(workspace, "REGENT_WORKFLOW.md"), workflow("primary"))
    File.write!(Path.join(workspace, "WORKFLOW.md"), workflow("secondary"))

    assert {:ok, loaded} = Workflows.load(workspace)
    assert loaded.config["name"] == "primary"
    assert loaded.source == "REGENT_WORKFLOW.md"
    assert loaded.path == Path.join(workspace, "REGENT_WORKFLOW.md")
  end

  test "loads WORKFLOW.md when REGENT_WORKFLOW.md is absent" do
    workspace = workspace_path("secondary")
    File.mkdir_p!(workspace)

    File.write!(Path.join(workspace, "WORKFLOW.md"), workflow("secondary"))

    assert {:ok, loaded} = Workflows.load(workspace)
    assert loaded.config["name"] == "secondary"
    assert loaded.source == "WORKFLOW.md"
    assert loaded.path == Path.join(workspace, "WORKFLOW.md")
  end

  test "returns a missing workflow error when no workflow file exists" do
    workspace = workspace_path("default")
    File.mkdir_p!(workspace)

    assert {:error, {:workflow_not_found, paths}} = Workflows.load(workspace)

    assert paths == [
             Path.join(workspace, "REGENT_WORKFLOW.md"),
             Path.join(workspace, "WORKFLOW.md")
           ]
  end

  test "reader discovery follows the same workflow order" do
    workspace = "/workspace"

    reader = fn
      "/workspace/REGENT_WORKFLOW.md" -> {:error, :missing_workflow}
      "/workspace/WORKFLOW.md" -> {:ok, workflow("reader-secondary")}
    end

    assert {:ok, loaded} = Discovery.load_from_reader(workspace, reader)
    assert loaded.config["name"] == "reader-secondary"
    assert loaded.source == "WORKFLOW.md"
    assert loaded.path == "/workspace/WORKFLOW.md"
  end

  test "reader discovery returns a missing workflow error when no workflow file is readable" do
    workspace = "/workspace"

    reader = fn _path -> {:error, :missing_workflow} end

    assert {:error, {:workflow_not_found, paths}} = Discovery.load_from_reader(workspace, reader)
    assert paths == ["/workspace/REGENT_WORKFLOW.md", "/workspace/WORKFLOW.md"]
  end

  defp workflow(name) do
    """
    ---
    name: #{name}
    ---
    Run #{name}.
    """
  end

  defp workspace_path(prefix) do
    Path.join(
      System.tmp_dir!(),
      "regent-workflow-#{prefix}-#{System.unique_integer([:positive])}"
    )
  end
end
