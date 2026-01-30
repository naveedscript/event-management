defmodule EventManagment.Workers.OrderConfirmationEmailTest do
  # Not async due to shared mock state
  use EventManagment.DataCase, async: false
  use Oban.Testing, repo: EventManagment.Repo

  alias EventManagment.Workers.OrderConfirmationEmail
  alias EventManagment.Notifications.EmailService

  describe "perform/1" do
    test "sends confirmation email for valid order" do
      order = insert(:order)

      assert :ok = perform_job(OrderConfirmationEmail, %{order_id: order.id})

      emails = EmailService.Mock.get_sent_emails()
      assert length(emails) == 1
      assert hd(emails).to == order.customer_email
      assert hd(emails).type == :order_confirmation
    end

    test "discards job when order not found" do
      assert :discard = perform_job(OrderConfirmationEmail, %{order_id: Ecto.UUID.generate()})
    end

    test "retries on email service timeout" do
      order = insert(:order)

      # Clear and set failure mode before performing job
      EmailService.Mock.clear()
      EmailService.Mock.set_failure_mode(:timeout)

      result = perform_job(OrderConfirmationEmail, %{order_id: order.id})
      assert {:error, "Email service timeout"} = result

      # Reset failure mode
      EmailService.Mock.set_failure_mode(nil)
    end

    test "job can be created with new/1" do
      order = insert(:order)

      job = OrderConfirmationEmail.new(%{order_id: order.id})
      assert job.changes.args == %{order_id: order.id}
      assert job.changes.queue == "emails"
    end

    test "uses emails queue" do
      order = insert(:order)

      changeset = OrderConfirmationEmail.new(%{order_id: order.id})
      assert changeset.changes.queue == "emails"
    end
  end

  describe "backoff/1" do
    test "uses exponential backoff" do
      # First attempt: 2^1 * 5 = 10 seconds
      assert OrderConfirmationEmail.backoff(%Oban.Job{attempt: 1}) == 10
      # Second attempt: 2^2 * 5 = 20 seconds
      assert OrderConfirmationEmail.backoff(%Oban.Job{attempt: 2}) == 20
      # Third attempt: 2^3 * 5 = 40 seconds
      assert OrderConfirmationEmail.backoff(%Oban.Job{attempt: 3}) == 40
    end
  end
end
