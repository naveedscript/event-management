defmodule EventManagment.Mailer do
  @moduledoc """
  Swoosh mailer for sending emails.
  """
  use Swoosh.Mailer, otp_app: :event_managment
end
