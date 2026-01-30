defmodule EventManagmentWeb.OrderJSON do
  alias EventManagment.Ticketing.Order

  def index(%{orders: orders}) do
    %{data: for(order <- orders, do: data(order))}
  end

  def show(%{order: order}) do
    %{data: data(order)}
  end

  defp data(%Order{} = order) do
    %{
      id: order.id,
      customer_email: order.customer_email,
      customer_name: order.customer_name,
      quantity: order.quantity,
      unit_price: order.unit_price,
      total_amount: order.total_amount,
      status: order.status,
      confirmed_at: order.confirmed_at,
      event: event_data(order.event),
      inserted_at: order.inserted_at,
      updated_at: order.updated_at
    }
  end

  defp event_data(nil), do: nil

  defp event_data(event) do
    %{
      id: event.id,
      name: event.name,
      venue: event.venue,
      date: event.date
    }
  end
end
