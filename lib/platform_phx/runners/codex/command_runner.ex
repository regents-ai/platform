defmodule PlatformPhx.Runners.Codex.CommandRunner do
  @moduledoc false

  def run(command, args, opts) when is_binary(command) and is_list(args) and is_list(opts) do
    cd = Keyword.fetch!(opts, :cd)
    input = Keyword.get(opts, :input, "")

    paths = temp_paths()

    try do
      with :ok <- File.write(paths.stdin, input),
           {_shell_output, status} <-
             System.cmd(
               "sh",
               ["-c", shell_script(command, args, paths.stdin, paths.stdout, paths.stderr)],
               cd: cd
             ) do
        {:ok,
         %{
           stdout: read_output(paths.stdout),
           stderr: read_output(paths.stderr),
           exit_status: status
         }}
      end
    rescue
      error -> {:error, Exception.message(error)}
    after
      cleanup(paths)
    end
  end

  defp temp_paths do
    base_path =
      Path.join(System.tmp_dir!(), "regent-codex-command-#{System.unique_integer([:positive])}")

    %{
      stdin: base_path <> ".stdin",
      stdout: base_path <> ".stdout",
      stderr: base_path <> ".stderr"
    }
  end

  defp read_output(path) do
    case File.read(path) do
      {:ok, output} -> output
      {:error, _reason} -> ""
    end
  end

  defp cleanup(paths) do
    File.rm(paths.stdin)
    File.rm(paths.stdout)
    File.rm(paths.stderr)
  end

  defp shell_script(command, args, stdin_path, stdout_path, stderr_path) do
    argv =
      [command | args]
      |> Enum.map_join(" ", &shell_quote/1)

    "#{argv} < #{shell_quote(stdin_path)} > #{shell_quote(stdout_path)} 2> #{shell_quote(stderr_path)}"
  end

  defp shell_quote(value) do
    "'#{String.replace(to_string(value), "'", "'\"'\"'")}'"
  end
end
