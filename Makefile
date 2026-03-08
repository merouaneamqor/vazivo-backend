.PHONY: help build up down restart logs shell console db-migrate db-seed db-reset test test-cov test-models test-requests test-services test-policies lint lint-fix security bundle clean

help:
	@echo "Backend Commands:"
	@echo "  make build        - Build Docker images (only needed for Dockerfile changes)"
	@echo "  make up           - Start all services"
	@echo "  make down         - Stop all services"
	@echo "  make restart      - Restart API and Sidekiq (apply Gemfile changes)"
	@echo "  make logs         - View logs"
	@echo "  make shell        - Open shell in API container"
	@echo "  make console      - Open Rails console"
	@echo "  make db-migrate   - Run database migrations"
	@echo "  make pre-deploy-local - Simulate Railway pre-deploy (db:migrate in one-off container; start db first)"
	@echo "  make db-seed      - Seed the database"
	@echo "  make db-reset     - Reset database"
	@echo ""
	@echo "Testing Commands:"
	@echo "  make test         - Run all tests"
	@echo "  make test-cov     - Run tests with coverage report"
	@echo "  make test-models  - Run model specs only"
	@echo "  make test-requests - Run request specs only"
	@echo "  make test-services - Run service specs only"
	@echo "  make test-policies - Run policy specs only"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint         - Run linter"
	@echo "  make lint-fix     - Run linter with auto-fix"
	@echo "  make security     - Run security scan (brakeman)"
	@echo ""
	@echo "Other:"
	@echo "  make bundle       - Install gems (after Gemfile changes)"
	@echo "  make clean        - Remove volumes and rebuild from scratch"

build:
	docker-compose build

up:
	@docker volume rm backend_bundle_cache 2>/dev/null || true
	docker-compose up -d

down:
	docker-compose down

restart:
	docker-compose restart api sidekiq

logs:
	docker-compose logs -f

shell:
	docker-compose exec api sh

console:
	docker-compose exec api rails console

db-migrate:
	docker-compose exec api rails db:migrate

# Simulate Railway pre-deploy: run migrations with DATABASE_URL (use when API is not running).
# Set DATABASE_URL or use default from docker-compose. Example:
#   make pre-deploy-local
#   DATABASE_URL=postgres://user:pass@host:5432/db make pre-deploy-local
pre-deploy-local:
	@echo "Running pre-deploy (rails db:migrate) with current DATABASE_URL..."
	docker-compose run --rm -e RAILS_ENV=$${RAILS_ENV:-staging} api sh -c 'bundle exec rails db:migrate'

db-seed:
	docker-compose exec api rails db:seed

db-reset:
	docker-compose exec api rails db:reset

# Testing targets
test:
	docker-compose exec api bundle exec rspec

test-cov:
	docker-compose exec -e COVERAGE=true api bundle exec rspec

test-models:
	docker-compose exec api bundle exec rspec spec/models

test-requests:
	docker-compose exec api bundle exec rspec spec/requests

test-services:
	docker-compose exec api bundle exec rspec spec/services

test-policies:
	docker-compose exec api bundle exec rspec spec/policies

test-presenters:
	docker-compose exec api bundle exec rspec spec/presenters

# Code quality targets
lint:
	docker-compose exec api bundle exec rubocop

lint-fix:
	docker-compose exec api bundle exec rubocop -A

security:
	docker-compose exec api bundle exec brakeman -q

bundle:
	docker-compose exec api bundle install

clean:
	docker-compose down -v --remove-orphans
	docker-compose build --no-cache
