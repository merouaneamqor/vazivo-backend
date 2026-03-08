# frozen_string_literal: true

# Runs the full prod_data load in Sidekiq so SSH can disconnect. Enqueue via: rails prod_data:load_async
class ProdDataLoadJob < ApplicationJob
  queue_as :default

  def perform
    ProdDataLoadService.call
  end
end
