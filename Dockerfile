# Dockerfile for Event Management System
# Multi-stage build for optimized production image

# Build stage
FROM elixir:1.19.5-otp-28-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

# Set build environment
ENV MIX_ENV=prod

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files first for better caching
COPY mix.exs mix.lock ./
COPY apps/event_managment/mix.exs apps/event_managment/
COPY apps/event_managment_web/mix.exs apps/event_managment_web/
COPY config/config.exs config/prod.exs config/runtime.exs config/

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY apps apps

# Compile the application
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Create non-root user
RUN addgroup -S app && adduser -S app -G app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/event_managment_umbrella ./

# Set ownership
RUN chown -R app:app /app

USER app

# Set environment variables
ENV HOME=/app
ENV MIX_ENV=prod
ENV PHX_SERVER=true

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/api/health || exit 1

# Start the application
CMD ["bin/event_managment_umbrella", "start"]
