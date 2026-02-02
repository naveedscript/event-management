defmodule EventManagment.Notifications.EmailService do
  @moduledoc """
  Behavior for email delivery. Implementation swapped via config.
  """

  @callback send_email(map()) :: :ok | {:error, term()}
  @callback send_order_confirmation(struct()) :: :ok | {:error, term()}

  @doc "Returns configured email service implementation."
  @spec impl() :: module()
  def impl do
    Application.get_env(:event_managment, :email_service, __MODULE__.Swoosh)
  end

  @spec send_email(map()) :: :ok | {:error, term()}
  def send_email(email), do: impl().send_email(email)

  @spec send_order_confirmation(struct()) :: :ok | {:error, term()}
  def send_order_confirmation(order), do: impl().send_order_confirmation(order)
end
