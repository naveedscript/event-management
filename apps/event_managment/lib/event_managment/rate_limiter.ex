defmodule EventManagment.RateLimiter do
  @moduledoc """
  Rate limiter using Hammer with ETS backend.
  """
  use Hammer, backend: :ets
end
