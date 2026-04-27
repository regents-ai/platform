defmodule Mix.Tasks.Platform.BetaReport do
  @moduledoc "Appends Platform beta check results to the Regent launch guide."
  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          host: :string,
          company_slug: :string,
          mobile: :boolean,
          dry_run: :boolean,
          json: :boolean
        ]
      )

    validate_args!(rest, invalid)

    report =
      PlatformPhx.Beta.Report.run(
        host: opts[:host],
        company_slug: opts[:company_slug],
        mobile?: opts[:mobile] == true
      )

    cond do
      opts[:json] ->
        Mix.shell().info(Jason.encode!(report, pretty: true))

      opts[:dry_run] ->
        Mix.shell().info(PlatformPhx.Beta.Report.markdown(report))

      true ->
        PlatformPhx.Beta.Report.append!(report)
        Mix.shell().info("Updated #{PlatformPhx.Beta.Report.default_run_sheet_path()}")
    end

    if report.status == "blocked", do: exit({:shutdown, 1})
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
