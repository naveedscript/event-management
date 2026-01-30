defmodule EventManagmentWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EventManagmentWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint EventManagmentWeb.Endpoint

      use EventManagmentWeb, :verified_routes

      # Import conveniences for testing with connections
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
    case EventManagment.Notifications.EmailService.Mock.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> EventManagment.Notifications.EmailService.Mock.clear()
    end

    case EventManagment.Payments.Gateway.Mock.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> EventManagment.Payments.Gateway.Mock.clear()
    end
  end
end
