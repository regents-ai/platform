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
           {:ok, _output} <- sprite_command_output(payload) do
        {:ok, sprite_success_result(payload)}
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
          {:ok, local_success_result(result)}

        {:ok, result} ->
          {:error,
           "Codex command failed with status #{result.exit_status}: #{local_command_error_output(result)}"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp sprite_success_result(payload) do
      output = sprite_stdout(payload)

      %{
        stdout: output,
        stderr: sprite_stderr(payload),
        proof: output,
        summary: "Codex finished the assigned work."
      }
    end

    defp local_success_result(result) do
      output = local_stdout(result)

      %{
        stdout: output,
        stderr: local_stderr(result),
        proof: output,
        summary: "Codex finished the assigned work."
      }
    end

    defp sprite_stdout(%{"stdout" => stdout}) when is_binary(stdout), do: stdout
    defp sprite_stdout(_payload), do: ""

    defp sprite_stderr(%{"stderr" => stderr}) when is_binary(stderr), do: stderr
    defp sprite_stderr(_payload), do: ""

    defp local_stdout(%{stdout: stdout}) when is_binary(stdout), do: stdout
    defp local_stdout(_result), do: ""

    defp local_stderr(%{stderr: stderr}) when is_binary(stderr), do: stderr
    defp local_stderr(_result), do: ""

    defp sprite_command_output(%{"exit_code" => 0} = payload), do: {:ok, sprite_stdout(payload)}

    defp sprite_command_output(%{"exit_code" => status} = payload),
      do:
        {:error,
         "Codex command failed with status #{status}: #{sprite_command_error_output(payload)}"}

    defp sprite_command_error_output(payload) do
      [sprite_stdout(payload), sprite_stderr(payload)]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end

    defp local_command_error_output(result) do
      [local_stdout(result), local_stderr(result)]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end

    defp shell_quote(value) do
      "'#{String.replace(to_string(value), "'", "'\"'\"'")}'"
    end
  end
end
