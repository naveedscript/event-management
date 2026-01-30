defmodule EventManagment.Payments.Gateway do
  @moduledoc """
  Behavior for payment gateway implementations.

  Defines the contract for payment processing. In a real system, you would
  have implementations for Stripe, PayPal, etc.

  ## Production Implementation
  Uses the configured payment provider (e.g., Stripe).

  ## Test Implementation
  Uses a mock that simulates payment processing.
  """

  @type payment_intent :: %{
          amount: Decimal.t(),
          currency: String.t(),
          customer_email: String.t(),
          description: String.t(),
          idempotency_key: String.t() | nil
        }

  @type charge_result ::
          {:ok, %{id: String.t(), status: String.t()}}
          | {:error, term()}

  @doc """
  Charges a payment.
  """
  @callback charge(payment_intent()) :: charge_result()

  @doc """
  Refunds a payment.
  """
  @callback refund(charge_id :: String.t()) :: {:ok, map()} | {:error, term()}

  @doc """
  Returns the configured payment gateway implementation.
  """
  def impl do
    Application.get_env(:event_managment, :payment_gateway, __MODULE__.Stripe)
  end

  @doc """
  Delegates to the configured implementation.
  """
  def charge(payment_intent), do: impl().charge(payment_intent)
  def refund(charge_id), do: impl().refund(charge_id)
end
