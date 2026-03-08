# frozen_string_literal: true

# Pagy initializer (backend-only; API returns meta in JSON, no HTML helpers needed)
require "pagy"
require "pagy/backend"

# Default items per page (controllers can override via params[:per_page])
Pagy::DEFAULT[:items] = 20
# Use :page from params (default)
Pagy::DEFAULT[:page_param] = :page
