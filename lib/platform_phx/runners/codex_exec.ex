defmodule PlatformPhx.Runners.CodexExec do
  @moduledoc false

  alias PlatformPhx.Runners.Codex.CommandRunner
  alias PlatformPhx.Runners.Codex.Lifecycle
  alias PlatformPhx.WorkRuns.WorkRun

  @runner_id "codex_exec"

  def run(%WorkRun{} = run) do
    Lifecycle.run(run,
      runner_id: @runner_id,
      proof_source: @runner_id,
      client: client()
    )
  end

  defp client do
    Application.get_env(:platform_phx, :codex_exec_client, __MODULE__.SystemCommandClient)
  end

  defmodule SystemCommandClient do
    @moduledoc false

    def run(%{workspace: %{kind: :sprite} = workspace}) do
      with {:ok, command} <- configured_command(),
           {:ok, runtime_id} <- sprite_runtime_id(workspace),
           {:ok, payload} <-
             PlatformPhx.RuntimeRegistry.SpritesClient.exec(runtime_id, %{
               "command" => sprite_command(command, workspace)
             }),
           {:ok, _output} <- command_output(payload) do
        {:ok, success_result(payload)}
      end
    rescue
      error -> {:error, Exception.message(error)}
    end

    def run(%{workspace: workspace, prompt: prompt}) do
      case configured_command() do
        {:ok, {command, args}} ->
          run_command(command, args, workspace.path, prompt)

        {:ok, command} ->
          run_command(command, [], workspace.path, prompt)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp configured_command do
      case Application.get_env(:platform_phx, :codex_exec_command) do
        {command, args} when is_binary(command) and is_list(args) -> {:ok, {command, args}}
        command when is_binary(command) -> {:ok, command}
        _missing -> {:error, "Codex execution command is not configured"}
      end
    end

    defp sprite_runtime_id(%{provider_runtime_id: runtime_id}) when is_binary(runtime_id),
      do: {:ok, runtime_id}

    defp sprite_runtime_id(_workspace), do: {:error, "Sprite runtime id is not configured"}

    defp sprite_command({command, args}, workspace) do
      command
      |> List.wrap()
      |> Kernel.++(args)
      |> Enum.map_join(" ", &shell_quote/1)
      |> sprite_command(workspace)
    end

    defp sprite_command(command, %{path: path}) when is_binary(command) do
      prompt_path = Path.join(path, PlatformPhx.Workspaces.prompt_file())

      "cd #{shell_quote(path)} && #{command} < #{shell_quote(prompt_path)}"
    end

    defp run_command(command, args, workspace_path, prompt) do
      case CommandRunner.run(command, args, cd: workspace_path, input: prompt) do
        {:ok, %{exit_status: 0} = result} ->
          {:ok, success_result(result)}

        {:ok, result} ->
          {:error,
           "Codex command failed with status #{result.exit_status}: #{command_error_output(result)}"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp success_result(payload) do
      output = stdout(payload)

      %{
        stdout: output,
        stderr: stderr(payload),
        proof: output,
        summary: "Codex finished the assigned work."
      }
    end

    defp stdout(payload) when is_map(payload),
      do: Map.get(payload, "stdout", Map.get(payload, :stdout, ""))

    defp stdout(_payload), do: ""

    defp stderr(payload) when is_map(payload),
      do: Map.get(payload, "stderr", Map.get(payload, :stderr, ""))

    defp stderr(_payload), do: ""

    defp command_output(%{"exit_code" => 0} = payload), do: {:ok, stdout(payload)}
    defp command_output(%{exit_code: 0} = payload), do: {:ok, stdout(payload)}

    defp command_output(%{"exit_code" => status} = payload),
      do: {:error, "Codex command failed with status #{status}: #{command_error_output(payload)}"}

    defp command_output(%{exit_code: status} = payload),
      do: {:error, "Codex command failed with status #{status}: #{command_error_output(payload)}"}

    defp command_error_output(payload) do
      [stdout(payload), stderr(payload)]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end

    defp shell_quote(value) do
      "'#{String.replace(to_string(value), "'", "'\"'\"'")}'"
    end
  end
end
