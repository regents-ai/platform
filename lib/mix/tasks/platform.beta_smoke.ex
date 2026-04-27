defmodule Mix.Tasks.Platform.BetaSmoke do
  @moduledoc "Runs the public beta smoke checks against a local or deployed Platform host."
  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [host: :string, company_slug: :string, mobile: :boolean, json: :boolean]
      )

    validate_args!(rest, invalid)

    result =
      PlatformPhx.Beta.Smoke.run(
        host: opts[:host],
        company_slug: opts[:company_slug],
        mobile?: opts[:mobile] == true
      )

    if opts[:json] do
      Mix.shell().info(Jason.encode!(result, pretty: true))
    else
      print_result(result)
    end

    if result.status == "blocked", do: exit({:shutdown, 1})
  end

  defp print_result(result) do
    Mix.shell().info("Platform beta smoke: #{result.status}")
    Mix.shell().info("Host: #{result.host}")

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
