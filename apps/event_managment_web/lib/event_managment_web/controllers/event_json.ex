defmodule EventManagmentWeb.EventJSON do
  alias EventManagment.Events.Event

  def index(%{events: events}) do
    %{data: for(event <- events, do: data(event))}
  end

  def show(%{event: event}) do
    %{data: data(event)}
  end

  defp data(%Event{} = event) do
    %{
      id: event.id,
      name: event.name,
      description: event.description,
      venue: event.venue,
      date: event.date,
      ticket_price: event.ticket_price,
      total_tickets: event.total_tickets,
      available_tickets: event.available_tickets,
      status: event.status,
      inserted_at: event.inserted_at,
      updated_at: event.updated_at
    }
  end
end
