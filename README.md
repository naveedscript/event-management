# Event Ticketing System

A RESTful API for event ticketing built with Elixir/Phoenix, demonstrating domain-driven design, background job processing, and testing best practices.

## Table of Contents

- [Setup](#setup)
- [Running Tests](#running-tests)
- [API Documentation](#api-documentation)
- [Architecture](#architecture)
- [Mocking Strategy](#mocking-strategy)
- [Background Jobs](#background-jobs)
- [Assumptions](#assumptions)

## Setup

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 14+

### Local Development

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start server
mix phx.server
```

API runs at `http://localhost:4000`

### Docker

```bash
docker-compose up
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| DATABASE_URL | Production | PostgreSQL connection string |
| SECRET_KEY_BASE | Production | Phoenix secret key |
| STRIPE_SECRET_KEY | Production | Stripe API key |

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific file
mix test apps/event_managment/test/event_managment/ticketing_test.exs
```

Tests use:
- Async sandbox mode for database isolation
- Mock implementations for external services (email, payments)
- Oban inline mode for synchronous job execution

## API Documentation

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/health | Health check |
| GET | /api/events | List events |
| GET | /api/events/:id | Get event |
| POST | /api/events | Create event |
| PUT | /api/events/:id | Update event |
| DELETE | /api/events/:id | Delete event |
| POST | /api/events/:id/publish | Publish event |
| POST | /api/events/:id/purchase | Purchase tickets |
| GET | /api/orders | List orders |
| GET | /api/orders/:id | Get order |
| POST | /api/orders/:id/cancel | Cancel order |

### Examples

**Create Event**
```bash
curl -X POST http://localhost:4000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "name": "Concert",
      "venue": "Stadium",
      "date": "2026-07-15T18:00:00Z",
      "ticket_price": "50.00",
      "total_tickets": 100
    }
  }'
```

**Purchase Tickets**
```bash
curl -X POST http://localhost:4000/api/events/{id}/purchase \
  -H "Content-Type: application/json" \
  -d '{
    "order": {
      "customer_email": "john@example.com",
      "customer_name": "John Doe",
      "quantity": 2,
      "idempotency_key": "unique-key-123"
    }
  }'
```

### Idempotency

Purchase requests support idempotency keys. If a request with the same key is repeated, the existing order is returned (not a 409 error). This allows safe retries on network failures.

### Rate Limiting

| Endpoint | Limit | Window |
|----------|-------|--------|
| General | 100 requests | 1 minute |
| Purchase | 10 requests | 1 minute |

### Postman

Import `postman_collection.json` for ready-to-use requests.

## Architecture

### Project Structure

```
apps/
├── event_managment/          # Business logic
│   ├── events/               # Event context
│   ├── ticketing/            # Order context
│   ├── notifications/        # Email context
│   ├── payments/             # Payment context
│   └── workers/              # Oban workers
└── event_managment_web/      # HTTP layer
    ├── controllers/
    └── plugs/
```

### Design Decisions

**1. Umbrella Application**

Separates business logic from web layer. The `event_managment` app has no Phoenix dependency and can be tested in isolation.

**2. Context Boundaries**

Each context exposes a public API. Cross-context communication happens through these APIs, not direct schema access.

```elixir
# Ticketing calls Events context
Events.decrement_tickets(event_id, quantity)

# Not direct Repo access
Repo.update(event, ...)
```

**3. Optimistic Locking for Inventory**

Prevents overselling under concurrent load using atomic updates:

```elixir
from(e in Event,
  where: e.id == ^id and e.available_tickets >= ^quantity
)
|> Repo.update_all(inc: [available_tickets: -quantity])
```

If another request decremented tickets first, the WHERE clause fails and the transaction rolls back.

**4. Row-Level Locking for Cancellations**

Prevents double-refund on concurrent cancel requests:

```elixir
from(o in Order, where: o.id == ^id, lock: "FOR UPDATE")
```

**5. Transaction Rollback on Any Failure**

Purchase flow is atomic. If payment or email enqueueing fails, tickets are returned:

```elixir
Repo.transaction(fn ->
  with {:ok, _} <- decrement_tickets(...),
       {:ok, _} <- process_payment(...),
       {:ok, _} <- create_order(...),
       :ok <- enqueue_email(...) do
    ...
  else
    {:error, reason} -> Repo.rollback(reason)
  end
end)
```

## Mocking Strategy

Uses "Mocking as a Noun" pattern - behaviors define contracts, implementations vary by environment.

### Mocked External Services

| Service | Production | Mock | Why Mock? |
|---------|------------|------|-----------|
| **Email** | Swoosh (SendGrid/Mailgun) | EmailService.Mock | Avoid sending real emails in tests, verify email content |
| **Payments** | Stripe API | Gateway.Mock | Avoid real charges, test failure scenarios (declined cards, timeouts) |

Both services are external dependencies that:
- Cost money per use (Stripe fees, email provider costs)
- Have side effects (actual charges, emails in inboxes)
- Can fail in ways we need to test (network timeouts, validation errors)
- Would make tests slow and flaky if called directly

### Structure

```elixir
# Behavior (contract)
defmodule Notifications.EmailService do
  @callback send_email(map()) :: :ok | {:error, term()}
end

# Production implementation
defmodule Notifications.EmailService.Swoosh do
  @behaviour Notifications.EmailService
  # Sends real emails via Swoosh
end

# Test implementation
defmodule Notifications.EmailService.Mock do
  @behaviour Notifications.EmailService
  # Stores emails in Agent for assertions
end
```

### Configuration

```elixir
# config/config.exs (production)
config :event_managment, :email_service, EmailService.Swoosh
config :event_managment, :payment_gateway, Gateway.Stripe

# config/test.exs
config :event_managment, :email_service, EmailService.Mock
config :event_managment, :payment_gateway, Gateway.Mock
```

### Benefits

- Compile-time contract verification
- No test pollution or global mocking state
- Easy to add new implementations (e.g., SendGrid, PayPal)
- Tests verify behavior, not implementation details

### Usage in Tests

```elixir
test "sends confirmation email" do
  {:ok, order} = Ticketing.purchase_tickets(event.id, attrs)

  emails = EmailService.Mock.get_sent_emails()
  assert hd(emails).to == "customer@example.com"
end

test "handles payment failure" do
  Gateway.Mock.set_failure_mode(:card_declined)

  assert {:error, {:payment_failed, _}} =
    Ticketing.purchase_tickets(event.id, attrs)
end
```

## Background Jobs

Uses Oban for reliable job processing with persistence, retries, and scheduling.

### Workers

| Worker | Queue | Trigger | Retries |
|--------|-------|---------|---------|
| OrderConfirmationEmail | emails | On purchase | 5 (exponential backoff) |
| EventCompletionJob | scheduled | Daily 00:00 UTC | 3 |

### Queues

| Queue | Concurrency | Purpose |
|-------|-------------|---------|
| default | 10 | General |
| emails | 5 | Notifications |
| scheduled | 2 | Cron jobs |

### Telemetry

Jobs emit events for monitoring:

```
[Oban] Completed: OrderConfirmationEmail in 45ms
[Oban] Failed: OrderConfirmationEmail - {:error, :timeout}
```

## Example Scenarios Handled

### 1. Concurrent Purchase
Two users try to buy the last ticket simultaneously.

**Solution:** Optimistic locking with atomic UPDATE. Only one succeeds, other gets `{:error, :insufficient_tickets}`.

```elixir
# Only updates if tickets still available
from(e in Event, where: e.available_tickets >= ^quantity)
|> Repo.update_all(inc: [available_tickets: -quantity])
```

**Test:** `test "handles concurrent purchases safely"` in `ticketing_test.exs`

### 2. Failed Notification
Email service is down when order is placed.

**Solution:** Email enqueueing failure rolls back entire transaction. Tickets returned, payment refunded.

```elixir
# In test
EmailService.Mock.set_failure_mode(:server_error)
assert {:error, {:email_enqueue_failed, _}} = Ticketing.purchase_tickets(...)
```

**Test:** Oban retries failed jobs with exponential backoff (5 attempts).

### 3. Invalid Purchase
User attempts to buy more tickets than available.

**Solution:** Atomic check in database query. Returns clear error.

```elixir
assert {:error, :insufficient_tickets} =
  Ticketing.purchase_tickets(event.id, %{quantity: 1000})
```

**Test:** `test "returns error when insufficient tickets"` in `ticketing_test.exs`

### 4. Event Completion
Daily job processes events whose dates have passed.

**Solution:** Oban cron job runs at midnight UTC, updates status from "published" to "completed".

```elixir
# Configured in config.exs
{Oban.Plugins.Cron, crontab: [{"0 0 * * *", EventCompletionJob}]}
```

**Test:** `test "marks past published events as completed"` in `event_completion_job_test.exs`

### 5. External Service Timeout
Payment or email service times out.

**Solution:** Mocks simulate timeouts. Transaction rolls back, tickets restored.

```elixir
# In test
Gateway.Mock.set_failure_mode(:timeout)
assert {:error, {:payment_failed, :timeout}} = Ticketing.purchase_tickets(...)

# Tickets not decremented
assert Events.get_event(event.id).available_tickets == 10
```

**Test:** `test "rolls back when payment fails"` in `ticketing_test.exs`

## Assumptions

1. **No Authentication** - API is open. Production would add JWT/session auth.

2. **Single Currency** - All prices in USD. Multi-currency would need schema changes.

3. **General Admission** - No seat selection. Reserved seating would need additional models.

4. **Synchronous Payment** - Stripe charges immediately. 3D Secure would need async flow.

5. **UTC Timezone** - All dates stored in UTC. Client handles display conversion.

6. **Max 10 Tickets/Order** - Business rule to prevent bulk buying.

7. **Email Delivery** - Uses Swoosh Local adapter in dev. Production needs SendGrid/Mailgun config.

8. **No Partial Refunds** - Cancellation refunds full amount. Partial refunds would need enhancement.
