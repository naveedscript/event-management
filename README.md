# Event Ticketing System

Event ticketing API built with Elixir/Phoenix.

## Setup

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

API runs at `http://localhost:4000`

### Docker

```bash
docker-compose up
```

## Tests

```bash
mix test
```

## API

### Events

```
GET    /api/events
GET    /api/events/:id
POST   /api/events
PUT    /api/events/:id
DELETE /api/events/:id
POST   /api/events/:id/publish
```

### Orders

```
POST   /api/events/:event_id/purchase
GET    /api/orders
GET    /api/orders/:id
POST   /api/orders/:id/cancel
```

### Health

```
GET    /api/health
```

## Example Requests

Create event:
```bash
curl -X POST http://localhost:4000/api/events \
  -H "Content-Type: application/json" \
  -d '{"event": {"name": "Concert", "venue": "Stadium", "date": "2026-07-15T18:00:00Z", "ticket_price": "50.00", "total_tickets": 100}}'
```

Purchase tickets:
```bash
curl -X POST http://localhost:4000/api/events/{id}/purchase \
  -H "Content-Type: application/json" \
  -d '{"order": {"customer_email": "john@example.com", "customer_name": "John Doe", "quantity": 2}}'
```

## Structure

```
apps/
├── event_managment/        # Business logic
│   ├── events/             # Event management
│   ├── ticketing/          # Order processing
│   ├── notifications/      # Email service
│   ├── payments/           # Payment gateway
│   └── workers/            # Background jobs
└── event_managment_web/    # API layer
```

## Key Features

- Race condition handling via optimistic locking
- Idempotency keys for purchase requests
- Background jobs with Oban (email notifications, scheduled tasks)
- Rate limiting (100 req/min general, 10 req/min purchases)
- Behavior-based mocking for external services
