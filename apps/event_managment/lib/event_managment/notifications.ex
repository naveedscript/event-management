defmodule EventManagment.Notifications do
  @moduledoc """
  Context for sending notifications (email, SMS, etc).
  """
  alias EventManagment.Notifications.EmailService
  alias EventManagment.Ticketing.Order

  @doc "Sends order confirmation email to customer."
  @spec send_order_confirmation(Order.t()) :: :ok | {:error, term()}
  def send_order_confirmation(order), do: EmailService.send_order_confirmation(order)

  @doc "Sends a generic email."
  @spec send_email(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def send_email(to, subject, body) do
    EmailService.send_email(%{to: to, subject: subject, body: body})
  end
end
