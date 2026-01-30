defmodule EventManagment.Payments.Gateway.Mock do
  @moduledoc """
  Mock payment gateway implementation for testing.

  Similar to the email mock, this stores payment attempts in an Agent
  and can be configured to simulate failures.

  ## Usage in Tests

      setup do
        Gateway.Mock.start_link()
        :ok
      end

      test "processes payment" do
        # ... trigger payment ...

        charges = Gateway.Mock.get_charges()
        assert length(charges) == 1
      end

      test "handles payment failure" do
        Gateway.Mock.set_failure_mode(:card_declined)
        # ... test error handling ...
      end

  """
  @behaviour EventManagment.Payments.Gateway

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(
      fn -> %{charges: [], refunds: [], failure_mode: nil} end,
      name: __MODULE__
    )
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
    - `:card_declined` - Simulates a declined card
    - `:insufficient_funds` - Simulates insufficient funds
    - `:timeout` - Simulates a timeout
    - `nil` - Normal operation (default)
  """
  def set_failure_mode(mode) do
    ensure_started()
    Agent.update(__MODULE__, fn state -> %{state | failure_mode: mode} end)
  end

  @doc """
  Returns all charges processed during the test.
  """
  def get_charges do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.charges end)
  end

  @doc """
  Returns all refunds processed during the test.
  """
  def get_refunds do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.refunds end)
  end

  @doc """
  Clears all recorded transactions.
  """
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

        Agent.update(__MODULE__, fn s ->
          %{s | charges: [charge | s.charges]}
        end)

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

        Agent.update(__MODULE__, fn s ->
          %{s | refunds: [refund | s.refunds]}
        end)

        {:ok, refund}
    end
  end
end
