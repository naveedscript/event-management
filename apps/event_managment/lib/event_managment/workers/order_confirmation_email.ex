defmodule EventManagment.Workers.OrderConfirmationEmail do
  @moduledoc """
  Oban worker for sending order confirmation emails asynchronously.

  This worker is enqueued after a successful ticket purchase and handles
  sending the confirmation email to the customer.

  ## Retry Policy

  - Max attempts: 5
  - Backoff: Exponential (10s, 20s, 40s, 80s, 160s)
  - Discards after final failure (logged for monitoring)

  ## Queue

  Uses the `:emails` queue with lower priority to avoid impacting
  critical operations.
  """
  use Oban.Worker,
    queue: :emails,
    max_attempts: 5,
    tags: ["notifications", "email"]

  alias EventManagment.Notifications
  alias EventManagment.Ticketing

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}, attempt: attempt}) do
    Logger.info("Sending order confirmation email for order #{order_id} (attempt #{attempt})")

    case Ticketing.get_order(order_id) do
      nil ->
        Logger.error("Order #{order_id} not found, discarding email job")
        :discard

      order ->
        case Notifications.send_order_confirmation(order) do
          :ok ->
            Logger.info("Successfully sent confirmation email for order #{order_id}")
            :ok

          {:error, :timeout} ->
            Logger.warning("Timeout sending email for order #{order_id}, will retry")
            {:error, "Email service timeout"}

          {:error, reason} ->
            Logger.error("Failed to send email for order #{order_id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 10s, 20s, 40s, 80s, 160s
    trunc(:math.pow(2, attempt) * 5)
  end
end
