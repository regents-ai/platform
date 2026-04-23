defmodule PlatformPhxWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  @prometheus_reporter :platform_phx_prometheus
  @request_duration_buckets [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
  @query_duration_buckets [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    _previous = :erlang.system_flag(:scheduler_wall_time, true)

    children = [
      {TelemetryMetricsPrometheus.Core,
       metrics: prometheus_metrics(), name: @prometheus_reporter, start_async: false},
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("platform_phx.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("platform_phx.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("platform_phx.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("platform_phx.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("platform_phx.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  def prometheus_reporter, do: @prometheus_reporter

  def prometheus_metrics do
    [
      counter("platform_phx.phoenix.requests.total",
        event_name: [:phoenix, :router_dispatch, :stop],
        measurement: fn _measurements, _metadata -> 1 end,
        tags: [:route],
        tag_values: &route_tag_values/1,
        description: "The total number of completed HTTP requests"
      ),
      counter("platform_phx.phoenix.request_exceptions.total",
        event_name: [:phoenix, :router_dispatch, :exception],
        measurement: fn _measurements, _metadata -> 1 end,
        tags: [:route],
        tag_values: &route_tag_values/1,
        description: "The total number of HTTP requests that raised an exception"
      ),
      distribution("platform_phx.phoenix.request.duration.seconds",
        event_name: [:phoenix, :router_dispatch, :stop],
        measurement: :duration,
        tags: [:route],
        tag_values: &route_tag_values/1,
        unit: {:native, :second},
        reporter_options: [buckets: @request_duration_buckets],
        description: "The HTTP request duration in seconds"
      ),
      counter("platform_phx.repo.queries.total",
        event_name: [:platform_phx, :repo, :query],
        measurement: fn _measurements, _metadata -> 1 end,
        description: "The total number of database queries"
      ),
      distribution("platform_phx.repo.query.duration.seconds",
        event_name: [:platform_phx, :repo, :query],
        measurement: :total_time,
        unit: {:native, :second},
        reporter_options: [buckets: @query_duration_buckets],
        description: "The total database query duration in seconds"
      ),
      counter("platform_phx.agent_formation.progress.total",
        event_name: [:platform_phx, :agent_formation, :progress],
        measurement: :count,
        tags: [:step, :status],
        description: "The total number of emitted company launch progress events"
      ),
      last_value("platform_phx.vm.memory.total.bytes",
        event_name: [:vm, :memory],
        measurement: :total,
        unit: :byte,
        description: "The total BEAM memory footprint in bytes"
      ),
      last_value("platform_phx.vm.run_queue.total",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :total,
        description: "The total BEAM run queue length"
      ),
      last_value("platform_phx.vm.run_queue.cpu",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :cpu,
        description: "The CPU scheduler run queue length"
      ),
      last_value("platform_phx.vm.run_queue.io",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :io,
        description: "The IO scheduler run queue length"
      ),
      last_value("platform_phx.vm.cpu.utilization.ratio",
        event_name: [:platform_phx, :vm, :cpu],
        measurement: :utilization,
        description: "The weighted scheduler utilization ratio"
      ),
      last_value("platform_phx.vm.scheduler.utilization.ratio",
        event_name: [:platform_phx, :vm, :scheduler],
        measurement: :utilization,
        description: "The aggregate scheduler utilization ratio"
      ),
      last_value("platform_phx.vm.process.count",
        event_name: [:platform_phx, :vm, :system_counts],
        measurement: :process_count,
        description: "The number of live BEAM processes"
      ),
      last_value("platform_phx.vm.port.count",
        event_name: [:platform_phx, :vm, :system_counts],
        measurement: :port_count,
        description: "The number of open BEAM ports"
      ),
      last_value("platform_phx.vm.ets.count",
        event_name: [:platform_phx, :vm, :system_counts],
        measurement: :ets_count,
        description: "The number of ETS tables"
      ),
      last_value("platform_phx.vm.atom.count",
        event_name: [:platform_phx, :vm, :system_counts],
        measurement: :atom_count,
        description: "The number of allocated atoms"
      )
    ]
  end

  def observe_runtime_stats do
    emit_system_counts()
    emit_scheduler_utilization()
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :observe_runtime_stats, []}
    ]
  end

  defp emit_system_counts do
    :telemetry.execute(
      [:platform_phx, :vm, :system_counts],
      %{
        atom_count: :erlang.system_info(:atom_count),
        ets_count: :erlang.system_info(:ets_count),
        port_count: :erlang.system_info(:port_count),
        process_count: :erlang.system_info(:process_count)
      },
      %{}
    )
  end

  defp emit_scheduler_utilization do
    sample = :scheduler.get_sample()

    case Process.get(:platform_phx_scheduler_sample) do
      nil ->
        Process.put(:platform_phx_scheduler_sample, sample)

      previous_sample ->
        Process.put(:platform_phx_scheduler_sample, sample)
        results = :scheduler.utilization(previous_sample, sample)

        :telemetry.execute(
          [:platform_phx, :vm, :cpu],
          %{utilization: scheduler_utilization(results, :weighted)},
          %{}
        )

        :telemetry.execute(
          [:platform_phx, :vm, :scheduler],
          %{utilization: scheduler_utilization(results, :total)},
          %{}
        )
    end
  end

  defp scheduler_utilization(results, kind) do
    Enum.find_value(results, 0.0, fn
      {^kind, value, _percent} -> value
      _other -> nil
    end)
  end

  defp route_tag_values(metadata) do
    %{route: metadata[:route] || "unmatched"}
  end
end
