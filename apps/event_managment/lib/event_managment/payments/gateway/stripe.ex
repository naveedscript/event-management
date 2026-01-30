defmodule EventManagment.Payments.Gateway.Stripe do
  @behaviour EventManagment.Payments.Gateway

  require Logger

  @impl true
  def charge(payment_intent) do
    amount_cents = payment_intent.amount |> Decimal.mult(100) |> Decimal.to_integer()

    params = %{
      amount: amount_cents,
      currency: payment_intent[:currency] || "usd",
      description: payment_intent[:description],
      receipt_email: payment_intent[:customer_email],
      metadata: %{
        idempotency_key: payment_intent[:idempotency_key]
      }
    }

    opts = build_opts(payment_intent[:idempotency_key])

    case Stripe.Charge.create(params, opts) do
      {:ok, %Stripe.Charge{id: id, status: status}} ->
        {:ok, %{id: id, status: status}}

      {:error, %Stripe.Error{message: message, code: code}} ->
        Logger.error("Stripe charge failed: #{code} - #{message}")
        {:error, %{code: code, message: message}}

      {:error, error} ->
        Logger.error("Stripe charge failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @impl true
  def refund(charge_id) do
    case Stripe.Refund.create(%{charge: charge_id}) do
      {:ok, %Stripe.Refund{id: id, status: status}} ->
        {:ok, %{id: id, charge_id: charge_id, status: status}}

      {:error, %Stripe.Error{message: message, code: code}} ->
        Logger.error("Stripe refund failed: #{code} - #{message}")
        {:error, %{code: code, message: message}}

      {:error, error} ->
        Logger.error("Stripe refund failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp build_opts(nil), do: []
  defp build_opts(idempotency_key), do: [idempotency_key: idempotency_key]
end
