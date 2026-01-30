defmodule EventManagment.Notifications do
  @moduledoc """
  The Notifications context - handles all notification-related operations.

  This context provides a facade over the email service, abstracting away
  the implementation details and providing a clean API for other contexts.

  ## Dependency Injection

  The actual email sending is delegated to a configurable implementation:
  - Production: `EmailService.Swoosh` - sends real emails via Swoosh
  - Test: `EmailService.Mock` - stores emails for test assertions

  This follows the "Mocking as a Noun" pattern - the mock is a real module
  that implements the same behavior, not a dynamic mock created at runtime.
  """

  alias EventManagment.Notifications.EmailService

  @doc """
  Sends an order confirmation email.

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  def send_order_confirmation(order) do
    EmailService.send_order_confirmation(order)
  end

  @doc """
  Sends a generic email.
  """
  def send_email(to, subject, body) do
    EmailService.send_email(%{to: to, subject: subject, body: body})
  end
end
