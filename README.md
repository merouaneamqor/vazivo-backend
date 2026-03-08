# Backend API - Ruby on Rails

A RESTful API for the booking platform built with Ruby on Rails 7.1.

## Requirements

- Docker & Docker Compose

## Quick Start

```bash
# Build and start
make build
make up

# View logs
make logs
```

The API will be available at `http://localhost:3000`

## Services

| Service | Port | Description |
|---------|------|-------------|
| API | 3000 | Rails API server |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache & Sidekiq |
| Sidekiq | - | Background jobs |

## Deploying to Railway (with Sidekiq)

To run background jobs on Railway, you need a **second service** that runs Sidekiq. See **[docs/RAILWAY_SIDEKIQ.md](docs/RAILWAY_SIDEKIQ.md)** for step-by-step setup (add worker service, set start command to `bundle exec sidekiq`, same REDIS_URL and env).

If you see PostgreSQL log messages like "database system was not properly shut down" or "invalid record length" after a restart, the database has already recovered. See **[docs/RAILWAY_POSTGRES_LOGS.md](docs/RAILWAY_POSTGRES_LOGS.md)** for details and how to use the readiness endpoint (`GET /up/ready`).

## Commands

```bash
make up          # Start services
make down        # Stop services
make logs        # View logs
make shell       # Shell into container
make console     # Rails console
make db-migrate  # Run migrations
make db-seed     # Seed database
make db-reset    # Reset database
make test        # Run tests
make lint        # Run linter
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register
- `POST /api/v1/auth/login` - Login
- `DELETE /api/v1/auth/logout` - Logout
- `GET /api/v1/auth/me` - Current user

### Resources
- `GET /api/v1/businesses` - List businesses
- `GET /api/v1/businesses/:id` - Get business
- `GET /api/v1/businesses/search` - Search businesses
- `GET /api/v1/services/:id/availability` - Get availability
- `POST /api/v1/bookings` - Create booking

## Demo Accounts

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@example.com | password123 |
| Provider | provider@example.com | password123 |
| Customer | customer@example.com | password123 |

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```
# Vazivo Backend
