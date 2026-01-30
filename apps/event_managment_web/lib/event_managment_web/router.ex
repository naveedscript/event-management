defmodule EventManagmentWeb.Router do
  use EventManagmentWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug EventManagmentWeb.Plugs.RateLimiter
  end

  scope "/api", EventManagmentWeb do
    pipe_through :api

    resources "/events", EventController, except: [:new, :edit] do
      post "/publish", EventController, :publish, as: :publish
    end

    post "/events/:event_id/purchase", OrderController, :purchase
    resources "/orders", OrderController, only: [:index, :show]
    post "/orders/:id/cancel", OrderController, :cancel

    get "/health", HealthController, :check
  end
end
