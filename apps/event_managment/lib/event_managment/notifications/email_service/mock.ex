defmodule EventManagment.Notifications.EmailService.Mock do
  @moduledoc """
  Mock email service implementation for testing.

  This implementation uses an Agent to store sent emails, allowing tests
  to verify that emails were sent correctly without actually sending them.

  ## Usage in Tests

      setup do
        EmailService.Mock.start_link()
        :ok
      end

      test "sends confirmation email" do
        # ... trigger email sending ...

        emails = EmailService.Mock.get_sent_emails()
        assert length(emails) == 1
        assert hd(emails).to == "customer@example.com"
      end

  """
  @behaviour EventManagment.Notifications.EmailService

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{emails: [], failure_mode: nil} end, name: __MODULE__)
  end

  @doc """
  Ensures the mock is started. Safe to call multiple times.
  """
  def ensure_started do
    case start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc """
  Configures the mock to simulate failures.

  ## Options
    - `:timeout` - Simulates a timeout error
    - `:server_error` - Simulates a server error
    - `nil` - Normal operation (default)

  ## Examples

      EmailService.Mock.set_failure_mode(:timeout)

  """
  def set_failure_mode(mode) do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | failure_mode: mode} end)
  end

  @doc """
  Returns all emails that have been "sent" during the test.
  """
  def get_sent_emails do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.emails end)
  end

  @doc """
  Clears all sent emails. Useful between tests.
  """
  def clear do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | emails: [], failure_mode: nil} end)
  end

  @impl true
  def send_email(email) do
    ensure_started()
    state = Agent.get(__MODULE__, & &1)

    case state.failure_mode do
      :timeout ->
        {:error, :timeout}

      :server_error ->
        {:error, :server_error}

      nil ->
        Agent.update(__MODULE__, fn s ->
          %{s | emails: [email | s.emails]}
        end)
        :ok
    end
  end

  @impl true
  def send_order_confirmation(order) do
    order = EventManagment.Repo.preload(order, :event)

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
