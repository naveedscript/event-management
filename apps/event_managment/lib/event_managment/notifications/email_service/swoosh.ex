defmodule EventManagment.Notifications.EmailService.Swoosh do
  @moduledoc """
  Production email service implementation using Swoosh.

  ## Configuration

  Configure the sender in `config/config.exs`:

      config :event_managment, EventManagment.Notifications.EmailService.Swoosh,
        from_email: "noreply@yourdomain.com",
        from_name: "Your App Name"

  """
  @behaviour EventManagment.Notifications.EmailService

  import Swoosh.Email

  alias EventManagment.Mailer

  @default_from_email "noreply@eventtickets.com"
  @default_from_name "Event Tickets"

  @impl true
  def send_email(%{to: to, subject: subject, body: body}) do
    {from_name, from_email} = get_from_config()

    email =
      new()
      |> to(to)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def send_order_confirmation(order) do
    order = EventManagment.Repo.preload(order, :event)

    body = build_confirmation_body(order)

    send_email(%{
      to: order.customer_email,
      subject: "Order Confirmation - #{order.event.name}",
      body: body
    })
  end

  defp get_from_config do
    config = Application.get_env(:event_managment, __MODULE__, [])
    from_email = Keyword.get(config, :from_email, @default_from_email)
    from_name = Keyword.get(config, :from_name, @default_from_name)
    {from_name, from_email}
  end

  defp build_confirmation_body(order) do
    """
    Dear #{order.customer_name},

    Thank you for your order!

    Order Details:
    - Order ID: #{order.id}
    - Event: #{order.event.name}
    - Date: #{format_date(order.event.date)}
    - Venue: #{order.event.venue}
    - Quantity: #{order.quantity} ticket(s)
    - Total: $#{order.total_amount}

    Please keep this email as your receipt.

    Best regards,
    #{get_from_name()} Team
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p UTC")
  end

  defp get_from_name do
    config = Application.get_env(:event_managment, __MODULE__, [])
    Keyword.get(config, :from_name, @default_from_name)
  end
end
