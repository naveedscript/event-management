defmodule EventManagment.Notifications.EmailService do
  @callback send_email(map()) :: :ok | {:error, term()}
  @callback send_order_confirmation(struct()) :: :ok | {:error, term()}

  def impl do
    Application.get_env(:event_managment, :email_service, __MODULE__.Swoosh)
  end

  def send_email(email), do: impl().send_email(email)
  def send_order_confirmation(order), do: impl().send_order_confirmation(order)
end
