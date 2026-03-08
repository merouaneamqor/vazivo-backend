# frozen_string_literal: true

require "net/http"

# Production data import: load businesses from JSON files into the database.
#
# Before loading, the task:
#   1. Deletes all data it will recreate: users with email ending in
#      ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS (@seed.vazivo.ma, @seed.glow.ma) and their
#      businesses (and dependents: services, bookings, reviews, etc.).
#   2. Unlinks services from non-canonical categories so Category.ensure_canonical_acts! can run without FK errors.
#   3. Ensures the 5 canonical Category acts exist (ensure_canonical_acts!).
# Then it (re)creates City, User (provider), and Business per JSON row.
#
# Data layout: prod_data/{city_slug}/{category_slug}/*.json (e.g. prod_data/casablanca/salon/salon.json).
# category_slug is mapped to one of the five canonical categories via Category.canonical_name_for_slug;
# unknown slugs default to "Salon de Beauté". Each JSON item may optionally include "category" (slug or name)
# to override the folder category; the value is normalized via Category.canonical_name_for_slug.
#
# Expected JSON keys per item: title (required), location, phone, website, description, image or images, category (optional).
#
# Flow:
#   0. Run db:migrate first so that required tables (users, businesses, categories, etc.) exist.
#   1. bundle exec rake prod_data:load
#      Cleans seed users/businesses, ensures canonical categories, creates City/User/Business per row.
#      Sets business.category and business.categories from the resolved canonical name.
#   2. Optional: PROD_DATA_SKIP_IMAGES=1 to skip image uploads; then run prod_data:enqueue_image_uploads to backfill.
#   3. prod_data:reset_categories is invoked automatically after load.
#
#   Async (recommended on Railway/SSH): rails prod_data:load_async — enqueues the load in Sidekiq and exits.
#
# ENV:
#   PROD_DATA_DIR          - Directory containing city/category/*.json (default: Rails.root/prod_data)
#   SEED_PROVIDER_PASSWORD - Password for created provider users
#   PROD_DATA_BATCH_SIZE   - Rows per batch (default 50)
#   PROD_DATA_SKIP_IMAGES  - Set to 1 to skip image uploads during load
#   DISCORD_WEBHOOK_URL    - Optional progress notifications
#   DISCORD_PROGRESS_EVERY - Notify every N businesses (default 100)
#
namespace :prod_data do
  PROD_DATA_DIR = Pathname.new(ENV["PROD_DATA_DIR"].presence || Rails.root.join("prod_data")).freeze
  SEED_PROVIDER_PASSWORD = ENV.fetch("SEED_PROVIDER_PASSWORD") do
    SecureRandom.hex(16).tap { |p| puts "⚠️  No SEED_PROVIDER_PASSWORD set; using one-time: #{p}" }
  end.freeze
  BATCH_SIZE = (ENV["PROD_DATA_BATCH_SIZE"] || 50).to_i
  DISCORD_PROGRESS_EVERY = (ENV["DISCORD_PROGRESS_EVERY"] || 100).to_i
  SKIP_IMAGES = ENV["PROD_DATA_SKIP_IMAGES"] == "1"

  # Database translations for the 5 canonical Category acts (en/fr/ar + slug). Used when ensuring categories on load.
  CANONICAL_ACT_TRANSLATIONS = [
    { en: "Salon de Beauté",  fr: "Salon de Beauté",  ar: "صالون تجميل",  slug: "salon-de-beaute" },
    { en: "Barber",           fr: "Barber",           ar: "حلاق رجال",    slug: "barber" },
    { en: "Hammam",           fr: "Hammam",           ar: "حمام",         slug: "hammam" },
    { en: "Massage & Spa",    fr: "Massage & Spa",    ar: "مساج وسبا",    slug: "massage-spa" },
    { en: "Nail Salon",       fr: "Institut Ongles",  ar: "صالون أظافر", slug: "nail-salon" },
  ].freeze

  def discord_notify(message)
    DiscordNotifier.notify(message)
  end

  desc "Initialize production (or any env) with businesses from backend/prod_data JSON files"
  task load: :environment do
    ProdDataLoadService.call(canonical_act_translations: CANONICAL_ACT_TRANSLATIONS) { |msg| puts msg }
  end

  desc "Enqueue prod_data load in Sidekiq and exit (safe to disconnect SSH); run: rails prod_data:load_async"
  task load_async: :environment do
    unless File.directory?(PROD_DATA_DIR)
      puts "❌ prod_data directory not found at #{PROD_DATA_DIR}"
      exit 1
    end
    unless User.table_exists? && Business.table_exists?
      puts "❌ Required database tables are missing. Run: rails db:migrate"
      exit 1
    end
    ProdDataLoadJob.perform_later
    puts "✅ Enqueued ProdDataLoadJob. Load will run in Sidekiq. Safe to disconnect."
  end

  desc "Reset categories from business.category so metadata counts are correct (run after prod_data:load)"
  task reset_categories: :environment do
    puts "🔄 Resetting categories from businesses..."
    ResetCategoriesFromBusinessesJob.perform_now
    puts "✅ Categories reset."
  end
end
