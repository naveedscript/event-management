defmodule EventManagment.NotificationsTest do
  use EventManagment.DataCase, async: false

  alias EventManagment.Notifications
  alias EventManagment.Notifications.EmailService

  describe "send_order_confirmation/1" do
    test "sends confirmation email for order" do
      order = insert(:order)
      order = EventManagment.Repo.preload(order, :event)

      assert :ok = Notifications.send_order_confirmation(order)

      emails = EmailService.Mock.get_sent_emails()
      assert length(emails) == 1

      email = hd(emails)
      assert email.to == order.customer_email
      assert email.subject =~ order.event.name
      assert email.type == :order_confirmation
    end

    test "returns error when email service fails" do
      order = insert(:order)
      order = EventManagment.Repo.preload(order, :event)

      EmailService.Mock.set_failure_mode(:timeout)

      assert {:error, :timeout} = Notifications.send_order_confirmation(order)

      EmailService.Mock.set_failure_mode(nil)
    end
  end

  describe "send_email/3" do
    test "sends generic email" do
      assert :ok = Notifications.send_email("user@example.com", "Test Subject", "Test body")

      emails = EmailService.Mock.get_sent_emails()
      assert length(emails) == 1

      email = hd(emails)
      assert email.to == "user@example.com"
      assert email.subject == "Test Subject"
      assert email.body == "Test body"
    end

    test "returns error on failure" do
      EmailService.Mock.set_failure_mode(:server_error)

      assert {:error, :server_error} = Notifications.send_email("user@example.com", "Test", "Body")

      EmailService.Mock.set_failure_mode(nil)
    end
  end
end
