defmodule EventManagment.ObanTelemetry do
  require Logger

  def attach do
    events = [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]

    :telemetry.attach_many("oban-logger", events, &__MODULE__.handle_event/4, nil)
  end

  def handle_event([:oban, :job, :start], _measurements, meta, _config) do
    Logger.debug("[Oban] Started: #{meta.worker} (#{meta.queue})")
  end

  def handle_event([:oban, :job, :stop], measurements, meta, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("[Oban] Completed: #{meta.worker} in #{duration_ms}ms")
  end

  def handle_event([:oban, :job, :exception], measurements, meta, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.error("[Oban] Failed: #{meta.worker} after #{duration_ms}ms - #{inspect(meta.reason)}")
  end
end
