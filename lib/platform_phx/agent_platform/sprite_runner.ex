defmodule PlatformPhx.AgentPlatform.SpriteRunner do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.Agent
  alias PlatformPhx.AgentPlatform.FormationRun
  alias PlatformPhx.AgentPlatform.WorkspaceBootstrap

  def run(%Agent{} = agent, %FormationRun{} = formation) do
    client().run(agent, formation)
  end

  def client do
    Application.get_env(:platform_phx, :agent_platform_sprite_runner, __MODULE__.CLI)
  end

  defmodule CLI do
    @moduledoc false

    alias PlatformPhx.AgentPlatform.Agent
    alias PlatformPhx.AgentPlatform.FormationRun
    alias PlatformPhx.AgentPlatform.WorkspaceBootstrap
    alias PlatformPhx.OperatorSecrets.SpriteControlSecret

    def run(%Agent{} = agent, %FormationRun{} = formation) do
      log_path =
        formation.sprite_command_log_path ||
          Path.join(System.tmp_dir!(), "agent-formation-#{agent.slug}-#{formation.id}.log")

      with {:ok, token} <- SpriteControlSecret.fetch_token() do
        env =
          WorkspaceBootstrap.build_env(agent, formation)
          |> Map.put("SPRITES_API_TOKEN", token)
          |> Enum.to_list()

        case System.cmd(
               WorkspaceBootstrap.script_path(),
               [],
               env: env,
               stderr_to_stdout: true
             ) do
          {output, 0} ->
            safe_output = sanitize_output(output, token)
            File.write!(log_path, safe_output)

            with {:ok, parsed} <- parse_last_json_line(safe_output) do
              {:ok, Map.put(parsed, "log_path", log_path)}
            end

          {output, _status} ->
            safe_output = sanitize_output(output, token)
            File.write!(log_path, safe_output)

            {:error,
             {:external, :sprite, "Sprite formation failed. See #{log_path} for details."}}
        end
      end
    end

    defp parse_last_json_line(output) do
      output
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reverse()
      |> Enum.find_value(fn line ->
        case Jason.decode(line) do
          {:ok, payload} -> payload
          _ -> nil
        end
      end)
      |> case do
        nil -> {:error, {:external, :sprite, "Sprite bootstrap did not return final JSON output"}}
        payload -> {:ok, payload}
      end
    end

    defp sanitize_output(output, token) do
      output
      |> String.replace(token, "[REDACTED]")
      |> Regex.replace(~r/(SPRITES_API_TOKEN=)[^\s]+/, "\\1[REDACTED]")
      |> Regex.replace(~r/(HERMES_PASSWORD=)[^\s]+/, "\\1[REDACTED]")
    end
  end
end
