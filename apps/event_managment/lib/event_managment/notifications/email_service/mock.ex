defmodule EventManagment.Notifications.EmailService.Mock do
  @moduledoc """
  Test implementation of EmailService. Stores emails in memory for assertions.
  """
  @behaviour EventManagment.Notifications.EmailService

  use Agent

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{emails: [], failure_mode: nil} end, name: __MODULE__)
  end

  def ensure_started do
    case start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc "Sets failure mode: :timeout, :server_error, or nil for success."
  @spec set_failure_mode(atom() | nil) :: :ok
  def set_failure_mode(mode) do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | failure_mode: mode} end)
  end

  @doc "Returns all sent emails for test assertions."
  @spec get_sent_emails() :: [map()]
  def get_sent_emails do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.emails end)
  end

  @doc "Clears stored emails and resets failure mode."
  @spec clear() :: :ok
  def clear do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | emails: [], failure_mode: nil} end)
  end

  @impl true
  def send_email(email) do
    ensure_started()
    state = Agent.get(__MODULE__, & &1)

    case state.failure_mode do
      :timeout -> {:error, :timeout}
      :server_error -> {:error, :server_error}
      nil ->
        Agent.update(__MODULE__, fn s -> %{s | emails: [email | s.emails]} end)
        :ok
    end
  end

  @impl true
  def send_order_confirmation(order) do
    email = %{
      to: order.customer_email,
      subject: "Order Confirmation - #{order.event.name}",
      body: "Order confirmation for #{order.customer_name}",
      order_id: order.id,
      type: :order_confirmation
    }

    send_email(email)
  end
end
