defmodule EventManagmentWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EventManagmentWeb.Endpoint

      use EventManagmentWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import EventManagmentWeb.ConnCase
      import EventManagment.Factory
    end
  end

  setup tags do
    EventManagment.DataCase.setup_sandbox(tags)
    start_mocks()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defp start_mocks do
    # Stop any existing agents first to ensure clean state
    try do
      Agent.stop(EventManagment.Notifications.EmailService.Mock)
    catch
      :exit, _ -> :ok
    end

    try do
      Agent.stop(EventManagment.Payments.Gateway.Mock)
    catch
      :exit, _ -> :ok
    end

    # Start fresh
    EventManagment.Notifications.EmailService.Mock.ensure_started()
    EventManagment.Payments.Gateway.Mock.ensure_started()
  end
end
