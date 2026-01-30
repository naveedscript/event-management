defmodule EventManagmentWeb.FallbackController do
  use EventManagmentWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: EventManagmentWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :not_found, message}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: EventManagmentWeb.ErrorJSON)
    |> render(:error, message: message)
  end

  def call(conn, {:error, :unprocessable_entity, message}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: EventManagmentWeb.ErrorJSON)
    |> render(:error, message: message)
  end

  def call(conn, {:error, :too_many_requests}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(json: EventManagmentWeb.ErrorJSON)
    |> render(:error, message: "Rate limit exceeded. Please try again later.")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: EventManagmentWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
