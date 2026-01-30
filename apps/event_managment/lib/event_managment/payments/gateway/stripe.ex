defmodule EventManagment.Payments.Gateway.Stripe do
  @moduledoc """
  Stripe payment gateway implementation.

  In a real implementation, this would use the Stripity Stripe library
  to communicate with the Stripe API.
  """
  @behaviour EventManagment.Payments.Gateway

  require Logger

  @impl true
  def charge(payment_intent) do
    # In production, this would call the Stripe API
    # For now, we simulate a successful charge
    Logger.info("Processing Stripe charge: #{inspect(payment_intent)}")

    {:ok,
     %{
       id: "ch_#{generate_id()}",
       status: "succeeded",
       amount: payment_intent.amount,
       currency: payment_intent[:currency] || "usd"
     }}
  end

  @impl true
  def refund(charge_id) do
    Logger.info("Processing Stripe refund for charge: #{charge_id}")

    {:ok,
     %{
       id: "re_#{generate_id()}",
       charge_id: charge_id,
       status: "succeeded"
     }}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end
end
