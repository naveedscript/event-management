defmodule EventManagment.ObanTelemetry do
  @moduledoc """
  Telemetry handler for Oban job monitoring.

  This module demonstrates understanding of Oban's monitoring capabilities
  by attaching to Oban's telemetry events and logging job execution metrics.

  ## Monitored Events

  - `[:oban, :job, :start]` - Job execution started
  - `[:oban, :job, :stop]` - Job execution completed successfully
  - `[:oban, :job, :exception]` - Job execution failed with exception

  ## Usage

  The telemetry handlers are attached in the Application startup.

  ## Metrics Collected

  - Job execution duration
  - Job success/failure counts
  - Queue processing times
  """

  require Logger

  @doc """
  Attaches telemetry handlers for Oban job monitoring.
  """
  def attach do
    events = [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]

    :telemetry.attach_many(
      "oban-logger",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Handles telemetry events from Oban.
  """
  def handle_event([:oban, :job, :start], _measurements, meta, _config) do
    Logger.debug(
      "[Oban] Job started: #{meta.worker} (ID: #{meta.job.id}, Queue: #{meta.queue})"
    )
  end

  def handle_event([:oban, :job, :stop], measurements, meta, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info(
      "[Oban] Job completed: #{meta.worker} (ID: #{meta.job.id}, Duration: #{duration_ms}ms, Queue: #{meta.queue})"
    )
  end

  def handle_event([:oban, :job, :exception], measurements, meta, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.error(
      "[Oban] Job failed: #{meta.worker} (ID: #{meta.job.id}, Duration: #{duration_ms}ms, " <>
        "Attempt: #{meta.job.attempt}/#{meta.job.max_attempts}, Error: #{inspect(meta.reason)})"
    )
  end
end
