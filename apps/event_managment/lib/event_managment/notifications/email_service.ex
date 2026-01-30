defmodule EventManagment.Notifications.EmailService do
  @moduledoc """
  Behavior for email service implementations.

  This defines the contract that all email service implementations must follow.
  Using behaviors allows us to swap implementations for testing (mocking as a noun).

  ## Production Implementation
  Uses Swoosh to send real emails via configured adapter.

  ## Test Implementation
  Uses a mock that stores emails in process state for assertions.
  """

  @type email :: %{
          to: String.t(),
          subject: String.t(),
          body: String.t()
        }

  @type send_result :: :ok | {:error, term()}

  @doc """
  Sends an email.
  """
  @callback send_email(email()) :: send_result()

  @doc """
  Sends an order confirmation email.
  """
  @callback send_order_confirmation(order :: struct()) :: send_result()

  @doc """
  Returns the configured email service implementation.
  """
  def impl do
    Application.get_env(:event_managment, :email_service, __MODULE__.Swoosh)
  end

  @doc """
  Delegates to the configured implementation.
  """
  def send_email(email), do: impl().send_email(email)
  def send_order_confirmation(order), do: impl().send_order_confirmation(order)
end
