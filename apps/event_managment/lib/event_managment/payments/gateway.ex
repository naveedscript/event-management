defmodule EventManagment.Payments.Gateway do
  @moduledoc """
  Behavior for payment processing. Implementation swapped via config.
  """

  @callback charge(map()) :: {:ok, map()} | {:error, term()}
  @callback refund(String.t()) :: {:ok, map()} | {:error, term()}

  @doc "Returns configured payment gateway implementation."
  @spec impl() :: module()
  def impl do
    Application.get_env(:event_managment, :payment_gateway) ||
      raise "No payment gateway configured. Set config :event_managment, :payment_gateway"
  end

  @doc "Charges a payment. Expects amount, currency, customer_email, description, idempotency_key."
  @spec charge(map()) :: {:ok, map()} | {:error, term()}
  def charge(payment_intent), do: impl().charge(payment_intent)

  @doc "Refunds a previously charged payment."
  @spec refund(String.t()) :: {:ok, map()} | {:error, term()}
  def refund(charge_id), do: impl().refund(charge_id)
end
