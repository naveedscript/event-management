defmodule EventManagment.Workers.EventCompletionJob do
  @moduledoc """
  Oban cron worker that marks past events as completed.

  Runs daily at midnight UTC to transition published events whose date has passed.
  """
  use Oban.Worker, queue: :scheduled, max_attempts: 3

  alias EventManagment.Events

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Running daily event completion job")
    {:ok, count} = Events.mark_past_events_completed()
    Logger.info("Marked #{count} events as completed")
    :ok
  end
end
