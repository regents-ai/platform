defmodule Mix.Tasks.Platform.Doctor do
  @moduledoc "Checks whether Platform is ready for the public beta deploy."
  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [json: :boolean])
    validate_args!(rest, invalid)

    result = PlatformPhx.Beta.Doctor.run()

    if opts[:json] do
      Mix.shell().info(Jason.encode!(result, pretty: true))
    else
      print_result(result)
    end

    if result.status == "blocked", do: exit({:shutdown, 1})
  end

  defp print_result(result) do
    Mix.shell().info("Platform doctor: #{result.status}")

    Enum.each(result.checks, fn check ->
      Mix.shell().info("  #{check.status} #{check.name}: #{check.message}")
    end)
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    Mix.raise(
      "Unknown arguments: #{Enum.join(rest ++ Enum.map(invalid, &format_invalid/1), ", ")}"
    )
  end

  defp format_invalid({key, nil}), do: key
  defp format_invalid({key, value}), do: "#{key}=#{value}"
end
