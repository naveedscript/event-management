defmodule EventManagment.Repo do
  use Ecto.Repo,
    otp_app: :event_managment,
    adapter: Ecto.Adapters.Postgres
end
