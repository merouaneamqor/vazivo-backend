# frozen_string_literal: true

# Runs the TripAdvisor seed file load in Sidekiq. Enqueue via: rails prod_data:load_seed_file_async
class ProdDataSeedFileLoadJob < ApplicationJob
  queue_as :default

  def perform(cleanup_seed_users: false)
    ProdDataSeedFileLoadService.call(cleanup_seed_users: cleanup_seed_users)
  end
end
