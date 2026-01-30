defmodule EventManagment.Workers.EventCompletionJobTest do
  use EventManagment.DataCase, async: true
  use Oban.Testing, repo: EventManagment.Repo

  alias EventManagment.Workers.EventCompletionJob
  alias EventManagment.Events

  describe "perform/1" do
    test "marks past published events as completed" do
      past_event =
        insert(:event, %{
          status: "published",
          date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      future_event = insert(:published_event)

      assert :ok = perform_job(EventCompletionJob, %{})

      assert Events.get_event(past_event.id).status == "completed"
      assert Events.get_event(future_event.id).status == "published"
    end

    test "does not affect draft events" do
      past_draft =
        insert(:event, %{
          status: "draft",
          date: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      assert :ok = perform_job(EventCompletionJob, %{})

      assert Events.get_event(past_draft.id).status == "draft"
    end

    test "handles no events gracefully" do
      assert :ok = perform_job(EventCompletionJob, %{})
    end
  end

  describe "job configuration" do
    test "uses scheduled queue" do
      {:ok, job} = EventCompletionJob.new(%{}) |> Oban.insert()
      assert job.queue == "scheduled"
    end

    test "has max 3 attempts" do
      {:ok, job} = EventCompletionJob.new(%{}) |> Oban.insert()
      assert job.max_attempts == 3
    end

    test "is scheduled via Oban cron at midnight daily" do
      config = Application.get_env(:event_managment, Oban)
      cron_plugin = Enum.find(config[:plugins], fn
        {Oban.Plugins.Cron, _} -> true
        _ -> false
      end)

      assert cron_plugin != nil
      {Oban.Plugins.Cron, cron_opts} = cron_plugin

      job_entry = Enum.find(cron_opts[:crontab], fn {_schedule, worker} ->
        worker == EventCompletionJob
      end)

      assert job_entry != nil
      assert {"0 0 * * *", EventCompletionJob} = job_entry
    end
  end
end
