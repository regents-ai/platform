defmodule PlatformPhx.Beta.Report do
  @moduledoc false

  alias PlatformPhx.Beta.Doctor
  alias PlatformPhx.Beta.Smoke

  @default_run_sheet Path.expand(
                       "../../../../docs/regent-local-and-fly-launch-testing.md",
                       __DIR__
                     )

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    doctor = Keyword.get_lazy(opts, :doctor, fn -> Doctor.run(opts) end)
    smoke = Keyword.get_lazy(opts, :smoke, fn -> Smoke.run(opts) end)
    gates = Keyword.get(opts, :gates, [])

    %{
      generated_at: now_iso(),
      status: overall_status([doctor, smoke] ++ gates),
      doctor: doctor,
      smoke: smoke,
      gates: gates
    }
  end

  @spec markdown(map()) :: String.t()
  def markdown(report) do
    """

    ## Platform Beta Check #{report.generated_at}

    Overall status: **#{report.status}**

    ### Doctor

    #{checks_table(report.doctor.checks)}

    ### Smoke

    Host: `#{report.smoke.host}`

    #{checks_table(report.smoke.checks)}

    ### Release Gates

    #{gates_table(report.gates)}
    """
  end

  @spec append!(map(), keyword()) :: :ok
  def append!(report, opts \\ []) do
    path = Keyword.get(opts, :path, @default_run_sheet)
    File.write!(path, markdown(report), [:append])
    :ok
  end

  def default_run_sheet_path, do: @default_run_sheet

  defp checks_table(checks) do
    rows =
      Enum.map(checks, fn check ->
        "| `#{check.name}` | #{check.status} | #{escape_pipe(check.message)} |"
      end)

    Enum.join(["| Check | Status | Notes |", "| --- | --- | --- |" | rows], "\n")
  end

  defp gates_table([]), do: "No release gate results were supplied."

  defp gates_table(gates) do
    rows =
      Enum.map(gates, fn gate ->
        "| `#{gate.name}` | #{gate.status} | #{escape_pipe(gate.message || "")} |"
      end)

    Enum.join(["| Gate | Status | Notes |", "| --- | --- | --- |" | rows], "\n")
  end

  defp overall_status(reports) do
    if Enum.any?(reports, &blocked?/1), do: "blocked", else: "pass"
  end

  defp blocked?(%{status: "blocked"}), do: true
  defp blocked?(_report), do: false

  defp escape_pipe(value), do: value |> to_string() |> String.replace("|", "\\|")

  defp now_iso do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
