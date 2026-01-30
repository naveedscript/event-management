defmodule EventManagmentWeb.Router do
  use EventManagmentWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug EventManagmentWeb.Plugs.RateLimiter
  end

  scope "/api", EventManagmentWeb do
    pipe_through :api

    # Events
    resources "/events", EventController, except: [:new, :edit] do
      # Nested routes for event-specific operations
      post "/publish", EventController, :publish, as: :publish
    end

    # Tickets/Orders
    post "/events/:event_id/purchase", OrderController, :purchase
    resources "/orders", OrderController, only: [:index, :show]
    post "/orders/:id/cancel", OrderController, :cancel

    # Health check
    get "/health", HealthController, :check
  end
end
