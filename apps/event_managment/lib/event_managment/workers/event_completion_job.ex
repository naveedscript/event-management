defmodule EventManagment.Workers.EventCompletionJob do
  @moduledoc """
  Oban worker for marking past events as completed.

  This job runs daily at midnight (configured in config.exs) and updates
  the status of all events whose date has passed from "published" to "completed".

  ## Schedule

  Configured as a cron job: `0 0 * * *` (daily at midnight UTC)

  ## Retry Policy

  - Max attempts: 3
  - Uses default backoff
  - Critical job - should be monitored for failures
  """
  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3,
    tags: ["maintenance", "events"]

  alias EventManagment.Events

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting daily event completion job")

    {:ok, count} = Events.mark_past_events_completed()
    Logger.info("Marked #{count} events as completed")
    :ok
  end
end
