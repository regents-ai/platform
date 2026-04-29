defmodule PlatformPhx.Workspaces do
  @moduledoc false

  alias PlatformPhx.RuntimeRegistry.RuntimeProfile
  alias PlatformPhx.WorkRuns.WorkRun
  alias PlatformPhx.Workflows

  @prompt_file "REGENT_PROMPT.md"
  @test_output_file "REGENT_TEST_OUTPUT.txt"

  def prepare(%WorkRun{} = run) do
    run = PlatformPhx.Repo.preload(run, [:runtime_profile])

    case run.runtime_profile do
      %RuntimeProfile{execution_surface: "hosted_sprite"} = profile ->
        __MODULE__.Sprite.prepare(run, profile)

      _profile ->
        __MODULE__.Local.prepare(run)
    end
  end

  def write_prompt(%{kind: :sprite} = workspace, prompt),
    do: __MODULE__.Sprite.write_prompt(workspace, prompt)

  def write_prompt(workspace, prompt), do: __MODULE__.Local.write_prompt(workspace, prompt)

  def load_workflow(%{kind: :sprite} = workspace), do: __MODULE__.Sprite.load_workflow(workspace)
  def load_workflow(workspace), do: Workflows.load(workspace.path)

  def collect(%{kind: :sprite} = workspace), do: __MODULE__.Sprite.collect(workspace)
  def collect(workspace), do: __MODULE__.Local.collect(workspace)

  def prompt_file, do: @prompt_file
  def test_output_file, do: @test_output_file

  defmodule Local do
    @moduledoc false

    def prepare(%WorkRun{} = run) do
      path =
        run.workspace_path ||
          Path.join(System.tmp_dir!(), "regent-rwr-run-#{run.id}")

      with :ok <- File.mkdir_p(path) do
        {:ok, %{kind: :local, path: path, run_id: run.id}}
      end
    end

    def write_prompt(%{path: path} = workspace, prompt) when is_binary(prompt) do
      prompt_path = Path.join(path, PlatformPhx.Workspaces.prompt_file())

      with :ok <- File.write(prompt_path, prompt) do
        {:ok, Map.put(workspace, :prompt_path, prompt_path)}
      end
    end

    def collect(%{path: path}) do
      {:ok,
       %{
         changed_files: changed_files(path),
         patch: git_output(path, ["diff", "--no-ext-diff", "--"]),
         test_output: test_output(path)
       }}
    end

    defp changed_files(path) do
      path
      |> git_output(["status", "--short"])
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        line
        |> String.slice(3..-1//1)
        |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))
    end

    defp test_output(path) do
      test_path = Path.join(path, PlatformPhx.Workspaces.test_output_file())

      case File.read(test_path) do
        {:ok, output} -> output
        {:error, _reason} -> ""
      end
    end

    defp git_output(path, args) do
      case System.cmd("git", args, cd: path, stderr_to_stdout: true) do
        {output, 0} -> output
        {_output, _status} -> ""
      end
    rescue
      _error -> ""
    end
  end

  defmodule Sprite do
    @moduledoc false

    def prepare(%WorkRun{} = run, %RuntimeProfile{} = profile) do
      case PlatformPhx.Workspaces.SpriteWorkspace.prepare_workspace(run, profile) do
        {:ok, workspace} ->
          workspace = Map.new(workspace)

          {:ok,
           workspace
           |> Map.new()
           |> Map.merge(%{
             kind: :sprite,
             run_id: run.id,
             runtime_profile_id: profile.id,
             path: Map.get(workspace, :path) || Map.get(workspace, "path") || run.workspace_path
           })}

        {:error, reason} ->
          {:error, reason}
      end
    end

    def write_prompt(workspace, prompt) do
      case PlatformPhx.Workspaces.SpriteWorkspace.write_prompt(workspace, prompt) do
        {:ok, attrs} -> {:ok, Map.merge(workspace, Map.new(attrs))}
        {:error, reason} -> {:error, reason}
      end
    end

    def load_workflow(workspace) do
      PlatformPhx.Workspaces.SpriteWorkspace.load_workflow(workspace)
    end

    def collect(workspace) do
      PlatformPhx.Workspaces.SpriteWorkspace.collect_artifacts(workspace)
    end
  end

  defmodule SpriteWorkspace do
    @moduledoc false

    alias PlatformPhx.RuntimeRegistry.RuntimeProfile
    alias PlatformPhx.WorkRuns.WorkRun
    alias PlatformPhx.Workflows

    def prepare_workspace(run, profile) do
      __MODULE__.Default.prepare_workspace(run, profile)
    end

    def write_prompt(workspace, prompt) do
      __MODULE__.Default.write_prompt(workspace, prompt)
    end

    def load_workflow(workspace) do
      __MODULE__.Default.load_workflow(workspace)
    end

    def collect_artifacts(workspace) do
      __MODULE__.Default.collect_artifacts(workspace)
    end

    defmodule Default do
      @moduledoc false

      def prepare_workspace(%WorkRun{} = run, %RuntimeProfile{} = profile) do
        with {:ok, runtime_id} <- PlatformPhx.RuntimeRegistry.provider_runtime_id(profile),
             path <- run.workspace_path || "/regent/workspaces/#{run.work_item_id}/#{run.id}",
             :ok <-
               exec_ok(
                 runtime_id,
                 "mkdir -p #{shell_quote(path)} #{shell_quote("/regent/artifacts/#{run.id}")}"
               ) do
          {:ok,
           %{
             kind: :sprite,
             run_id: run.id,
             runtime_profile_id: profile.id,
             provider_runtime_id: runtime_id,
             path: path
           }}
        end
      end

      def write_prompt(%{provider_runtime_id: runtime_id, path: path}, prompt)
          when is_binary(prompt) do
        prompt_path = Path.join(path, PlatformPhx.Workspaces.prompt_file())
        encoded_prompt = Base.encode64(prompt)

        with :ok <-
               exec_ok(
                 runtime_id,
                 "printf %s #{shell_quote(encoded_prompt)} | base64 -d > #{shell_quote(prompt_path)}"
               ) do
          {:ok, %{prompt_path: prompt_path}}
        end
      end

      def load_workflow(%{provider_runtime_id: runtime_id, path: path}) do
        Workflows.Discovery.load_from_reader(path, fn workflow_path ->
          read_workflow(runtime_id, workflow_path)
        end)
      end

      def collect_artifacts(%{provider_runtime_id: runtime_id, path: path}) do
        with {:ok, changed_files} <-
               exec(
                 runtime_id,
                 "cd #{shell_quote(path)} && git status --short 2>/dev/null || true"
               ),
             {:ok, patch} <-
               exec(
                 runtime_id,
                 "cd #{shell_quote(path)} && git diff --no-ext-diff -- 2>/dev/null || true"
               ),
             {:ok, test_output} <-
               exec(
                 runtime_id,
                 "cat #{shell_quote(Path.join(path, PlatformPhx.Workspaces.test_output_file()))} 2>/dev/null || true"
               ) do
          {:ok,
           %{
             changed_files: parse_changed_files(stdout(changed_files)),
             patch: stdout(patch),
             test_output: stdout(test_output)
           }}
        end
      end

      defp exec_ok(runtime_id, command) do
        case exec(runtime_id, command) do
          {:ok, _payload} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end

      defp exec(runtime_id, command) do
        PlatformPhx.RuntimeRegistry.SpritesClient.exec(runtime_id, %{"command" => command})
      end

      defp read_workflow(runtime_id, workflow_path) do
        with {:ok, payload} <- exec(runtime_id, "cat #{shell_quote(workflow_path)} 2>/dev/null") do
          case payload do
            %{"exit_code" => 0} -> {:ok, stdout(payload)}
            %{exit_code: 0} -> {:ok, stdout(payload)}
            %{"exit_code" => _status} -> {:error, :missing_workflow}
            %{exit_code: _status} -> {:error, :missing_workflow}
            _payload -> {:error, :missing_workflow}
          end
        end
      end

      defp parse_changed_files(output) do
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          line
          |> String.slice(3..-1//1)
          |> String.trim()
        end)
        |> Enum.reject(&(&1 == ""))
      end

      defp stdout(payload) when is_map(payload),
        do: Map.get(payload, "stdout", Map.get(payload, :stdout, ""))

      defp stdout(_payload), do: ""

      defp shell_quote(value) do
        "'#{String.replace(to_string(value), "'", "'\"'\"'")}'"
      end
    end
  end
end
