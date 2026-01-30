defmodule EventManagment.Notifications do
  alias EventManagment.Notifications.EmailService

  def send_order_confirmation(order), do: EmailService.send_order_confirmation(order)

  def send_email(to, subject, body) do
    EmailService.send_email(%{to: to, subject: subject, body: body})
  end
end
