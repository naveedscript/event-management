defmodule EventManagment.Payments.Gateway.Mock do
  @moduledoc """
  Test implementation of payment gateway. Stores charges/refunds in memory.
  """
  @behaviour EventManagment.Payments.Gateway

  use Agent

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{charges: [], refunds: [], failure_mode: nil} end, name: __MODULE__)
  end

  def ensure_started do
    case start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc "Sets failure mode: :card_declined, :insufficient_funds, :timeout, or nil."
  @spec set_failure_mode(atom() | nil) :: :ok
  def set_failure_mode(mode) do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | failure_mode: mode} end)
  end

  @doc "Returns all charges for test assertions."
  @spec get_charges() :: [map()]
  def get_charges do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.charges end)
  end

  @doc "Returns all refunds for test assertions."
  @spec get_refunds() :: [map()]
  def get_refunds do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.refunds end)
  end

  @doc "Clears stored data and resets failure mode."
  @spec clear() :: :ok
  def clear do
    ensure_started()
    Agent.update(__MODULE__, fn state ->
      %{state | charges: [], refunds: [], failure_mode: nil}
    end)
  end

  @impl true
  def charge(payment_intent) do
    ensure_started()
    state = Agent.get(__MODULE__, & &1)

    case state.failure_mode do
      :card_declined ->
        {:error, %{code: "card_declined", message: "Your card was declined"}}

      :insufficient_funds ->
        {:error, %{code: "insufficient_funds", message: "Insufficient funds"}}

      :timeout ->
        {:error, :timeout}

      nil ->
        charge = %{
          id: "ch_mock_#{System.unique_integer([:positive])}",
          status: "succeeded",
          amount: payment_intent.amount,
          currency: payment_intent[:currency] || "usd",
          created_at: DateTime.utc_now()
        }

        Agent.update(__MODULE__, fn s -> %{s | charges: [charge | s.charges]} end)
        {:ok, charge}
    end
  end

  @impl true
  def refund(charge_id) do
    ensure_started()
    state = Agent.get(__MODULE__, & &1)

    case state.failure_mode do
      :timeout ->
        {:error, :timeout}

      _ ->
        refund = %{
          id: "re_mock_#{System.unique_integer([:positive])}",
          charge_id: charge_id,
          status: "succeeded",
          created_at: DateTime.utc_now()
        }

        Agent.update(__MODULE__, fn s -> %{s | refunds: [refund | s.refunds]} end)
        {:ok, refund}
    end
  end
end
