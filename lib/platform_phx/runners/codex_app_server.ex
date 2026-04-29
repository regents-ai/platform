defmodule PlatformPhx.Runners.CodexAppServer do
  @moduledoc false

  alias PlatformPhx.Runners.Codex.Lifecycle
  alias PlatformPhx.WorkRuns.WorkRun

  @runner_id "codex_app_server"

  def run(%WorkRun{} = run) do
    Lifecycle.run(run,
      runner_id: @runner_id,
      proof_source: @runner_id,
      client: client()
    )
  end

  defp client do
    Application.get_env(:platform_phx, :codex_app_server_client, __MODULE__.AppServerClient)
  end

  defmodule AppServerClient do
    @moduledoc false

    @initialize_id 1
    @thread_start_id 2
    @turn_start_id 3
    @port_line_bytes 1_048_576
    @request_timeout_ms 15_000
    @turn_timeout_ms 600_000

    def run(%{workspace: %{kind: :sprite}}) do
      {:error, "Codex App Server runner requires an interactive app-server session"}
    end

    def run(%{workspace: %{path: workspace_path}, prompt: prompt} = payload)
        when is_binary(workspace_path) and is_binary(prompt) do
      with {:ok, command} <- configured_command(),
           {:ok, port} <- start_port(command, workspace_path) do
        try do
          with :ok <- initialize(port),
               {:ok, thread_id} <- start_thread(port, workspace_path),
               {:ok, _turn_id} <- start_turn(port, thread_id, payload, workspace_path),
               {:ok, result} <- await_turn_completed(port, []) do
            {:ok, result}
          end
        after
          close_port(port)
        end
      end
    end

    def run(_payload), do: {:error, "Codex App Server runner needs a local workspace and prompt"}

    defp configured_command do
      case Application.get_env(:platform_phx, :codex_app_server_command) do
        {command, args} when is_binary(command) and is_list(args) -> {:ok, {:exec, command, args}}
        command when is_binary(command) -> {:ok, {:shell, command}}
        _missing -> {:error, "Codex App Server command is not configured"}
      end
    end

    defp start_port({:shell, command}, workspace_path) do
      case System.find_executable("bash") do
        nil ->
          {:error, "bash is not available to start Codex App Server"}

        bash ->
          port =
            Port.open({:spawn_executable, String.to_charlist(bash)}, [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: [~c"-lc", String.to_charlist(command)],
              cd: String.to_charlist(workspace_path),
              line: @port_line_bytes
            ])

          {:ok, port}
      end
    end

    defp start_port({:exec, command, args}, workspace_path) do
      port =
        Port.open({:spawn_executable, String.to_charlist(command)}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: Enum.map(args, &String.to_charlist/1),
          cd: String.to_charlist(workspace_path),
          line: @port_line_bytes
        ])

      {:ok, port}
    end

    defp initialize(port) do
      send_message(port, %{
        "method" => "initialize",
        "id" => @initialize_id,
        "params" => %{
          "capabilities" => %{"experimentalApi" => true},
          "clientInfo" => %{
            "name" => "regent-platform",
            "title" => "Regent Platform",
            "version" => "0.1.0"
          }
        }
      })

      with {:ok, _result} <- await_response(port, @initialize_id) do
        send_message(port, %{"method" => "initialized", "params" => %{}})
      end
    end

    defp start_thread(port, workspace_path) do
      send_message(port, %{
        "method" => "thread/start",
        "id" => @thread_start_id,
        "params" => %{
          "approvalPolicy" => approval_policy(),
          "sandbox" => thread_sandbox(),
          "cwd" => workspace_path,
          "dynamicTools" => []
        }
      })

      case await_response(port, @thread_start_id) do
        {:ok, %{"thread" => %{"id" => thread_id}}} ->
          {:ok, thread_id}

        {:ok, result} ->
          {:error, "Codex App Server returned an invalid thread response: #{inspect(result)}"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp start_turn(port, thread_id, payload, workspace_path) do
      send_message(port, %{
        "method" => "turn/start",
        "id" => @turn_start_id,
        "params" => %{
          "threadId" => thread_id,
          "input" => [%{"type" => "text", "text" => payload.prompt}],
          "cwd" => workspace_path,
          "title" => turn_title(payload),
          "approvalPolicy" => approval_policy(),
          "sandboxPolicy" => turn_sandbox_policy()
        }
      })

      case await_response(port, @turn_start_id) do
        {:ok, %{"turn" => %{"id" => turn_id}}} ->
          {:ok, turn_id}

        {:ok, result} ->
          {:error, "Codex App Server returned an invalid turn response: #{inspect(result)}"}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp await_response(port, id) do
      case receive_message(port, @request_timeout_ms) do
        {:ok, %{"id" => ^id, "result" => result}} ->
          {:ok, result}

        {:ok, %{"id" => ^id, "error" => error}} ->
          {:error, "Codex App Server request #{id} failed: #{inspect(error)}"}

        {:ok, _message} ->
          await_response(port, id)

        {:error, reason} ->
          {:error, format_receive_error(reason)}
      end
    end

    defp await_turn_completed(port, messages) do
      case receive_message(port, @turn_timeout_ms) do
        {:ok, %{"method" => "turn/completed"} = message} ->
          {:ok, success_result(message, messages)}

        {:ok, %{"method" => method, "params" => params}}
        when method in ["turn/failed", "turn/cancelled"] ->
          {:error, "Codex App Server #{method}: #{inspect(params)}"}

        {:ok, %{"method" => method}}
        when method in [
               "item/commandExecution/requestApproval",
               "item/fileChange/requestApproval",
               "item/tool/requestUserInput"
             ] ->
          {:error, "Codex App Server requested interactive approval: #{method}"}

        {:ok, message} ->
          await_turn_completed(port, [message | messages])

        {:error, reason} ->
          {:error, format_receive_error(reason)}
      end
    end

    defp send_message(port, payload) do
      Port.command(port, Jason.encode!(payload) <> "\n")
      :ok
    end

    defp receive_message(port, timeout_ms) do
      receive do
        {^port, {:data, {:eol, line}}} ->
          decode_message(line)

        {^port, {:data, {:noeol, line}}} ->
          receive_continued_message(port, timeout_ms, to_string(line))

        {^port, {:exit_status, status}} ->
          {:error, {:exit_status, status}}
      after
        timeout_ms ->
          {:error, :timeout}
      end
    end

    defp receive_continued_message(port, timeout_ms, pending) do
      receive do
        {^port, {:data, {:eol, line}}} ->
          decode_message(pending <> to_string(line))

        {^port, {:data, {:noeol, line}}} ->
          receive_continued_message(port, timeout_ms, pending <> to_string(line))

        {^port, {:exit_status, status}} ->
          {:error, {:exit_status, status}}
      after
        timeout_ms ->
          {:error, :timeout}
      end
    end

    defp decode_message(line) do
      case Jason.decode(to_string(line)) do
        {:ok, message} when is_map(message) ->
          {:ok, message}

        {:ok, _message} ->
          {:error, {:invalid_message, line}}

        {:error, _reason} ->
          {:error, {:invalid_message, line}}
      end
    end

    defp success_result(completed_message, messages) do
      ordered_messages = Enum.reverse([completed_message | messages])
      output = output_text(completed_message, ordered_messages)

      %{
        stdout: output,
        stderr: "",
        proof: proof_text(output),
        proof_title: "Codex App Server proof",
        summary: "Codex App Server finished the assigned work.",
        events: Enum.map(ordered_messages, &client_event/1)
      }
    end

    defp output_text(completed_message, messages) do
      completed_message
      |> text_from_message()
      |> case do
        "" ->
          messages
          |> Enum.map(&text_from_message/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("\n")

        output ->
          output
      end
    end

    defp text_from_message(%{"params" => params}) when is_map(params) do
      params
      |> Map.take(["output", "text", "message", "delta"])
      |> Map.values()
      |> Enum.find_value("", &string_value/1)
    end

    defp text_from_message(_message), do: ""

    defp string_value(value) when is_binary(value), do: value
    defp string_value(value) when is_map(value), do: Jason.encode!(value)
    defp string_value(_value), do: nil

    defp proof_text(""), do: "Codex App Server completed the assigned work."
    defp proof_text(output), do: output

    defp client_event(%{"method" => method, "params" => params}) do
      %{kind: "codex.app_server.message", payload: %{method: method, params: params || %{}}}
    end

    defp client_event(%{"method" => method}) do
      %{kind: "codex.app_server.message", payload: %{method: method, params: %{}}}
    end

    defp turn_title(%{run: %{id: run_id, work_item: %{title: title}}})
         when not is_nil(run_id) and is_binary(title),
         do: "run-#{run_id}: #{title}"

    defp turn_title(%{run: %{id: run_id}}) when not is_nil(run_id), do: "run-#{run_id}"
    defp turn_title(_payload), do: "Regent Codex run"

    defp approval_policy do
      Application.get_env(:platform_phx, :codex_app_server_approval_policy, "never")
    end

    defp thread_sandbox do
      Application.get_env(:platform_phx, :codex_app_server_thread_sandbox, "workspace-write")
    end

    defp turn_sandbox_policy do
      Application.get_env(:platform_phx, :codex_app_server_turn_sandbox_policy, %{
        "mode" => "workspace-write"
      })
    end

    defp format_receive_error(:timeout), do: "Codex App Server timed out"

    defp format_receive_error({:exit_status, status}),
      do: "Codex App Server exited with status #{status}"

    defp format_receive_error({:invalid_message, line}) do
      output =
        line
        |> to_string()
        |> String.slice(0, 500)

      "Codex App Server emitted invalid protocol output: #{output}"
    end

    defp format_receive_error(reason), do: "Codex App Server failed: #{inspect(reason)}"

    defp close_port(port) do
      if is_port(port) and Port.info(port) != nil do
        Port.close(port)
      end

      :ok
    rescue
      ArgumentError -> :ok
    end
  end
end
