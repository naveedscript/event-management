defmodule EventManagment.Workers.OrderConfirmationEmail do
  use Oban.Worker, queue: :emails, max_attempts: 5

  alias EventManagment.Notifications
  alias EventManagment.Ticketing

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}, attempt: attempt}) do
    Logger.info("Sending confirmation email for order #{order_id} (attempt #{attempt})")

    case Ticketing.get_order(order_id) do
      nil ->
        Logger.error("Order #{order_id} not found, discarding job")
        :discard

      order ->
        case Notifications.send_order_confirmation(order) do
          :ok ->
            Logger.info("Sent confirmation email for order #{order_id}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to send email for order #{order_id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(2, attempt) * 5)
  end
end
