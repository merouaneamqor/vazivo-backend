# Geocoding Service

Periodic job to geocode businesses that have addresses but missing coordinates.

## Setup

1. Install the gem:
```bash
bundle install
```

2. Restart Sidekiq to load the scheduler:
```bash
# Development
bundle exec sidekiq

# Production (if using systemd/docker)
systemctl restart sidekiq
# or
docker-compose restart sidekiq
```

## Configuration

The job is configured in `config/sidekiq.yml`:
- Runs daily at 2 AM
- Processes up to 50 businesses per run
- Respects Nominatim rate limit (1 req/sec)

## Manual Trigger

To manually trigger geocoding:

```ruby
# In Rails console
GeocodeBusinessesJob.perform_now

# Or with custom batch size
GeocodeBusinessesJob.perform_now(batch_size: 100)
```

## How It Works

1. `GeocodeBusinessesJob` finds businesses with addresses but no coordinates
2. Enqueues individual `BusinessGeocodeJob` for each business
3. Each job calls `GeocodingService.geocode` using Nominatim API
4. Updates business with lat/lng (triggers h3_index and geo_validated)
