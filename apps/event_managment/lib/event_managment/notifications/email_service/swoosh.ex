defmodule EventManagment.Notifications.EmailService.Swoosh do
  @behaviour EventManagment.Notifications.EmailService

  import Swoosh.Email

  alias EventManagment.Mailer

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
    send_email(%{
      to: order.customer_email,
      subject: "Order Confirmation - #{order.event.name}",
      body: build_confirmation_body(order)
    })
  end

  defp get_from_config do
    config = Application.get_env(:event_managment, __MODULE__, [])
    from_email = Keyword.get(config, :from_email, "noreply@eventtickets.com")
    from_name = Keyword.get(config, :from_name, "Event Tickets")
    {from_name, from_email}
  end

  defp build_confirmation_body(order) do
    {from_name, _} = get_from_config()

    """
    Dear #{order.customer_name},

    Thank you for your order!

    Order Details:
    - Order ID: #{order.id}
    - Event: #{order.event.name}
    - Date: #{Calendar.strftime(order.event.date, "%B %d, %Y at %I:%M %p UTC")}
    - Venue: #{order.event.venue}
    - Quantity: #{order.quantity} ticket(s)
    - Total: $#{order.total_amount}

    Please keep this email as your receipt.

    Best regards,
    #{from_name} Team
    """
  end
end
