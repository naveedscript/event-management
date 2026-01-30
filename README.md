# Event Ticketing System

A simplified event ticketing system API built with Elixir/Phoenix, demonstrating proficiency in backend development, domain-driven design, background job processing, and testing best practices.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Setup Instructions](#setup-instructions)
- [Running Tests](#running-tests)
- [API Documentation](#api-documentation)
- [Mocking Strategy](#mocking-strategy)
- [Architecture Decisions](#architecture-decisions)
- [Assumptions](#assumptions)

## Overview

This system provides a RESTful API for:
- **Event Management**: Create, read, update, and list events
- **Ticket Purchasing**: Purchase tickets with inventory validation and race condition handling
- **Order Management**: View and manage orders
- **Background Processing**: Async email notifications and scheduled maintenance jobs

### Tech Stack

- **Elixir 1.19.5** / **Erlang/OTP 28**
- **Phoenix 1.8.3** (API-only)
- **PostgreSQL** (via Ecto)
- **Oban** for background job processing
- **Swoosh** for email delivery
- **Hammer** for rate limiting

## Architecture

### Umbrella Application Structure

```
event_managment_umbrella/
├── apps/
│   ├── event_managment/         # Core business logic
│   │   ├── lib/
│   │   │   ├── event_managment/
│   │   │   │   ├── events/      # Events context
│   │   │   │   ├── ticketing/   # Ticketing context
│   │   │   │   ├── notifications/  # Notifications context
│   │   │   │   ├── payments/    # Payments context
│   │   │   │   └── workers/     # Oban background workers
│   │   │   └── event_managment.ex
│   │   └── priv/repo/migrations/
│   └── event_managment_web/     # Web layer (API)
│       └── lib/
│           └── event_managment_web/
│               ├── controllers/
│               └── plugs/
├── config/
├── docker-compose.yml
└── Dockerfile
```

### Domain Contexts

| Context | Responsibility |
|---------|---------------|
| **Events** | Event lifecycle management, ticket inventory |
| **Ticketing** | Order processing, purchase validation |
| **Notifications** | Email delivery abstraction |
| **Payments** | Payment processing abstraction |

### Context Boundaries

Contexts communicate through well-defined interfaces and never directly access each other's internal modules:

```elixir
# Good - Using context public API
EventManagment.Events.decrement_tickets(event_id, quantity)

# Bad - Direct schema access across contexts (avoided)
EventManagment.Events.Event |> Repo.get(id) |> ...
```

## Setup Instructions

### Prerequisites

- Elixir 1.19.5+
- Erlang/OTP 28+
- PostgreSQL 14+
- (Optional) Docker & Docker Compose

### Local Development

1. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd event_managment
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   ```

3. **Setup database**
   ```bash
   mix ecto.setup
   ```

4. **Start the server**
   ```bash
   mix phx.server
   ```

   The API will be available at `http://localhost:4000`

### Using Docker

1. **Start services**
   ```bash
   docker-compose up -d db
   docker-compose up app
   ```

2. **Run migrations (first time)**
   ```bash
   docker-compose exec app mix ecto.setup
   ```

### Production Build

```bash
docker build -t event-ticketing .
docker run -e DATABASE_URL=... -e SECRET_KEY_BASE=... -p 4000:4000 event-ticketing
```

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test apps/event_managment/test/event_managment/events_test.exs

# Run tests in parallel
mix test --max-cases 8
```

Tests run in sandbox mode and don't require external services.

## API Documentation

### Base URL
```
http://localhost:4000/api
```

### Events

#### List Events
```http
GET /api/events
GET /api/events?status=published
GET /api/events?upcoming=true
```

#### Get Event
```http
GET /api/events/:id
```

#### Create Event
```http
POST /api/events
Content-Type: application/json

{
  "event": {
    "name": "Summer Concert",
    "description": "Annual summer music festival",
    "venue": "Central Park",
    "date": "2026-07-15T18:00:00Z",
    "ticket_price": "75.00",
    "total_tickets": 1000
  }
}
```

#### Update Event
```http
PUT /api/events/:id
Content-Type: application/json

{
  "event": {
    "name": "Updated Event Name"
  }
}
```

#### Delete Event
```http
DELETE /api/events/:id
```

#### Publish Event
```http
POST /api/events/:id/publish
```

### Orders

#### Purchase Tickets
```http
POST /api/events/:event_id/purchase
Content-Type: application/json

{
  "order": {
    "customer_email": "john@example.com",
    "customer_name": "John Doe",
    "quantity": 2,
    "idempotency_key": "unique-request-id-123"  // Optional
  }
}
```

#### List Orders
```http
GET /api/orders
GET /api/orders?customer_email=john@example.com
GET /api/orders?event_id=<uuid>
```

#### Get Order
```http
GET /api/orders/:id
```

#### Cancel Order
```http
POST /api/orders/:id/cancel
```

### Health Check
```http
GET /api/health
```

### Error Responses

```json
{
  "errors": {
    "detail": "Event not found"
  }
}
```

```json
{
  "errors": {
    "customer_email": ["can't be blank"],
    "quantity": ["must be greater than 0"]
  }
}
```

## Mocking Strategy

This project uses **"Mocking as a Noun"** - behaviors define contracts, with different implementations for production and test environments.

### Email Service

```elixir
# Behavior definition
defmodule EventManagment.Notifications.EmailService do
  @callback send_email(email()) :: :ok | {:error, term()}
  @callback send_order_confirmation(order()) :: :ok | {:error, term()}
end

# Production implementation
defmodule EventManagment.Notifications.EmailService.Swoosh do
  @behaviour EventManagment.Notifications.EmailService
  # Uses Swoosh to send real emails
end

# Test implementation
defmodule EventManagment.Notifications.EmailService.Mock do
  @behaviour EventManagment.Notifications.EmailService
  # Stores emails in Agent for test assertions
end
```

### Configuration

```elixir
# config/config.exs (production)
config :event_managment, :email_service, EventManagment.Notifications.EmailService.Swoosh

# config/test.exs
config :event_managment, :email_service, EventManagment.Notifications.EmailService.Mock
```

### Usage in Tests

```elixir
test "sends confirmation email" do
  # Purchase tickets (triggers email)
  {:ok, order} = Ticketing.purchase_tickets(event.id, attrs)

  # Verify email was "sent" via mock
  emails = EmailService.Mock.get_sent_emails()
  assert length(emails) == 1
  assert hd(emails).to == "customer@example.com"
end

test "handles email service timeout" do
  EmailService.Mock.set_failure_mode(:timeout)
  # Test error handling...
end
```

### Payment Gateway

Similarly, the payment gateway uses the same pattern with `Gateway.Stripe` (production) and `Gateway.Mock` (test).

## Architecture Decisions

### 1. Umbrella Application

**Decision**: Use Phoenix umbrella structure with separate apps for business logic and web layer.

**Rationale**:
- Clear separation between domain logic and HTTP concerns
- Business logic can be tested without web dependencies
- Enables potential extraction to separate services later

### 2. Optimistic Locking for Inventory

**Decision**: Use `UPDATE ... WHERE available_tickets >= quantity` for atomic ticket decrement.

**Rationale**:
- Prevents overselling under concurrent load
- No external locking mechanism required
- Single query instead of read-then-write

```elixir
query = from e in Event,
  where: e.id == ^event_id and e.available_tickets >= ^quantity

Repo.update_all(query, [inc: [available_tickets: -quantity]], returning: true)
```

### 3. Idempotency Keys

**Decision**: Support optional `idempotency_key` on purchases.

**Rationale**:
- Prevents duplicate charges on network retries
- Client can safely retry failed requests
- Unique constraint ensures atomicity

### 4. Oban for Background Jobs

**Decision**: Use Oban instead of simple Task.async or GenServer.

**Rationale**:
- Persistent job storage (survives restarts)
- Built-in retry with configurable backoff
- Cron-like scheduling for maintenance jobs
- Telemetry for monitoring

### 5. Behavior-based Mocking

**Decision**: Use Elixir behaviors instead of dynamic mocking libraries.

**Rationale**:
- Compile-time contract verification
- No test pollution or global state
- Clear documentation of external service interfaces
- Easier to reason about test vs production behavior

## Assumptions

1. **No Authentication**: The API doesn't require authentication. In production, you'd add JWT/session-based auth.

2. **Single Currency**: All prices are assumed to be in USD. Multi-currency would require additional schema fields.

3. **No Payment Processing**: The payment gateway is mocked. Real implementation would integrate with Stripe/PayPal.

4. **Email Delivery**: Uses Swoosh with Local adapter in dev. Production would use SendGrid/Mailgun/etc.

5. **Timezone**: All dates are stored and returned in UTC. Client-side conversion is expected.

6. **Maximum 10 Tickets Per Order**: Business rule to prevent bulk purchases. Configurable if needed.

7. **No Seat Selection**: Tickets are general admission. Reserved seating would require additional schema.

8. **Immediate Confirmation**: Orders are confirmed immediately upon successful inventory decrement. Real systems might have a pending state for payment processing.

## Oban Job Monitoring

The system includes telemetry-based job monitoring:

```elixir
# Logged events:
[Oban] Job started: EventManagment.Workers.OrderConfirmationEmail (ID: 123, Queue: emails)
[Oban] Job completed: EventManagment.Workers.OrderConfirmationEmail (ID: 123, Duration: 45ms)
[Oban] Job failed: ... (Attempt: 2/5, Error: ...)
```

For production, consider adding:
- Oban Web UI for visual monitoring
- StatsD/Prometheus metrics export
- Alert rules for failed jobs

## Rate Limiting

API endpoints are rate-limited using Hammer:

| Endpoint Type | Limit | Window |
|--------------|-------|--------|
| General API | 100 requests | 1 minute |
| Purchase | 10 requests | 1 minute |

Rate limiting is disabled in test environment.

## License

MIT
