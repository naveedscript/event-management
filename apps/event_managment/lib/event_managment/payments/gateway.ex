defmodule EventManagment.Payments.Gateway do
  @callback charge(map()) :: {:ok, map()} | {:error, term()}
  @callback refund(String.t()) :: {:ok, map()} | {:error, term()}

  def impl do
    Application.get_env(:event_managment, :payment_gateway) ||
      raise "No payment gateway configured. Set config :event_managment, :payment_gateway"
  end

  def charge(payment_intent), do: impl().charge(payment_intent)
  def refund(charge_id), do: impl().refund(charge_id)
end
