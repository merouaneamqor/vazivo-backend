# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_03_06_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_activity_logs", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "action", null: false
    t.string "resource_type", null: false
    t.string "resource_id"
    t.jsonb "details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_admin_activity_logs_on_admin_user_id"
    t.index ["created_at"], name: "index_admin_activity_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_admin_activity_logs_on_resource_type_and_resource_id"
  end

  create_table "booking_events", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["booking_id", "created_at"], name: "index_booking_events_on_booking_id_and_created_at"
  end

  create_table "booking_payments", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "user_id", null: false
    t.string "stripe_payment_intent_id"
    t.string "stripe_customer_id"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "mad"
    t.string "status", default: "pending"
    t.jsonb "metadata", default: {}
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_booking_payments_on_booking_id"
    t.index ["status"], name: "index_booking_payments_on_status"
    t.index ["stripe_payment_intent_id"], name: "index_booking_payments_on_stripe_payment_intent_id", unique: true
    t.index ["user_id"], name: "index_booking_payments_on_user_id"
  end

  create_table "booking_services", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "service_id", null: false
    t.bigint "staff_id"
    t.decimal "price", precision: 10, scale: 2
    t.integer "duration_minutes"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "service_id"], name: "index_booking_services_on_booking_id_and_service_id", unique: true
    t.index ["booking_id"], name: "index_booking_services_on_booking_id"
    t.index ["service_id"], name: "index_booking_services_on_service_id"
    t.index ["staff_id"], name: "index_booking_services_on_staff_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "business_id", null: false
    t.date "date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "total_price", precision: 10, scale: 2
    t.text "notes"
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.string "customer_name"
    t.string "customer_phone"
    t.string "customer_email"
    t.string "short_booking_id", null: false
    t.bigint "staff_id"
    t.index ["business_id"], name: "index_bookings_on_business_id"
    t.index ["cancelled_at"], name: "index_bookings_on_cancelled_at"
    t.index ["confirmed_at"], name: "index_bookings_on_confirmed_at"
    t.index ["date"], name: "index_bookings_on_date"
    t.index ["short_booking_id"], name: "index_bookings_on_short_booking_id", unique: true
    t.index ["staff_id", "date", "start_time"], name: "index_bookings_on_staff_date_start_time_active", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying])::text[]))"
    t.index ["staff_id", "date", "start_time"], name: "index_bookings_on_staff_id_and_date_and_start_time"
    t.index ["staff_id"], name: "index_bookings_on_staff_id"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "business_categories", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "category_id"], name: "index_business_categories_on_business_id_and_category_id", unique: true
  end

  create_table "business_claim_requests", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id"
    t.string "email", null: false
    t.string "name", null: false
    t.text "message"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "status"], name: "index_business_claim_requests_on_business_id_and_status"
    t.index ["business_id"], name: "index_business_claim_requests_on_business_id"
    t.index ["status"], name: "index_business_claim_requests_on_status"
    t.index ["user_id"], name: "index_business_claim_requests_on_user_id"
  end

  create_table "business_search_indices", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "city_id"
    t.bigint "category_id"
    t.float "rating", default: 0.0, null: false
    t.integer "reviews_count", default: 0, null: false
    t.decimal "lat", precision: 10, scale: 8
    t.decimal "lng", precision: 11, scale: 8
    t.string "h3_index"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_business_search_indices_on_business_id", unique: true
    t.index ["city_id", "category_id"], name: "index_business_search_indices_on_city_id_and_category_id"
    t.index ["h3_index"], name: "index_business_search_indices_on_h3_index"
    t.index ["rating"], name: "index_business_search_indices_on_rating"
    t.index ["reviews_count"], name: "index_business_search_indices_on_reviews_count"
  end

  create_table "business_staffs", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "staff"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "user_id"], name: "index_business_staffs_on_business_id_and_user_id", unique: true
    t.index ["business_id"], name: "index_business_staffs_on_business_id"
    t.index ["user_id"], name: "index_business_staffs_on_user_id"
  end

  create_table "business_statistics", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.integer "phone_clicks", default: 0, null: false
    t.integer "profile_views", default: 0, null: false
    t.integer "booking_clicks", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "google_maps_clicks", default: 0, null: false
    t.integer "waze_clicks", default: 0, null: false
    t.index ["business_id"], name: "index_business_statistics_on_business_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "category", null: false
    t.string "address", null: false
    t.string "city", null: false
    t.decimal "lat", precision: 10, scale: 8
    t.decimal "lng", precision: 11, scale: 8
    t.jsonb "opening_hours", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "slug"
    t.string "h3_index"
    t.string "verification_status", default: "pending", null: false
    t.boolean "geo_validated", default: false, null: false
    t.integer "onboarding_score", default: 0, null: false
    t.string "neighborhood"
    t.jsonb "categories", default: []
    t.string "country", default: "Morocco"
    t.datetime "published_at"
    t.datetime "premium_expires_at"
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.text "description_en"
    t.text "description_fr"
    t.text "description_ar"
    t.string "slug_en"
    t.string "slug_fr"
    t.string "slug_ar"
    t.string "logo"
    t.jsonb "gallery_images", default: []
    t.bigint "city_id"
    t.bigint "neighborhood_id"
    t.float "average_rating", default: 0.0, null: false
    t.integer "reviews_count", default: 0, null: false
    t.index ["category"], name: "index_businesses_on_category"
    t.index ["city"], name: "index_businesses_on_city"
    t.index ["city_id"], name: "index_businesses_on_city_id"
    t.index ["discarded_at"], name: "index_businesses_on_discarded_at"
    t.index ["h3_index"], name: "index_businesses_on_h3_index"
    t.index ["lat", "lng"], name: "index_businesses_on_lat_and_lng"
    t.index ["neighborhood_id"], name: "index_businesses_on_neighborhood_id"
    t.index ["onboarding_score"], name: "index_businesses_on_onboarding_score"
    t.index ["premium_expires_at"], name: "index_businesses_on_premium_expires_at", where: "(premium_expires_at IS NOT NULL)"
    t.index ["published_at"], name: "index_businesses_on_published_at", where: "(published_at IS NOT NULL)"
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
    t.index ["slug_ar"], name: "index_businesses_on_slug_ar", unique: true, where: "(slug_ar IS NOT NULL)"
    t.index ["slug_en"], name: "index_businesses_on_slug_en", unique: true, where: "(slug_en IS NOT NULL)"
    t.index ["slug_fr"], name: "index_businesses_on_slug_fr", unique: true, where: "(slug_fr IS NOT NULL)"
    t.index ["user_id"], name: "index_businesses_on_user_id"
    t.index ["verification_status"], name: "index_businesses_on_verification_status"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.string "slug_en"
    t.string "slug_fr"
    t.string "slug_ar"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
    t.index ["slug_ar"], name: "index_categories_on_slug_ar", unique: true, where: "(slug_ar IS NOT NULL)"
    t.index ["slug_en"], name: "index_categories_on_slug_en", unique: true, where: "(slug_en IS NOT NULL)"
    t.index ["slug_fr"], name: "index_categories_on_slug_fr", unique: true, where: "(slug_fr IS NOT NULL)"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.string "slug_en"
    t.string "slug_fr"
    t.string "slug_ar"
    t.decimal "lat", precision: 10, scale: 8
    t.decimal "lng", precision: 11, scale: 8
    t.index ["slug"], name: "index_cities_on_slug", unique: true
    t.index ["slug_ar"], name: "index_cities_on_slug_ar", unique: true, where: "(slug_ar IS NOT NULL)"
    t.index ["slug_en"], name: "index_cities_on_slug_en", unique: true, where: "(slug_en IS NOT NULL)"
    t.index ["slug_fr"], name: "index_cities_on_slug_fr", unique: true, where: "(slug_fr IS NOT NULL)"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "email"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.index ["business_id", "email"], name: "index_clients_on_business_id_and_email"
    t.index ["business_id"], name: "index_clients_on_business_id"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "neighborhoods", force: :cascade do |t|
    t.bigint "city_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.string "slug_en"
    t.string "slug_fr"
    t.string "slug_ar"
    t.index ["city_id", "slug"], name: "index_neighborhoods_on_city_id_and_slug", unique: true
    t.index ["city_id", "slug_ar"], name: "index_neighborhoods_on_city_id_and_slug_ar", unique: true, where: "(slug_ar IS NOT NULL)"
    t.index ["city_id", "slug_en"], name: "index_neighborhoods_on_city_id_and_slug_en", unique: true, where: "(slug_en IS NOT NULL)"
    t.index ["city_id", "slug_fr"], name: "index_neighborhoods_on_city_id_and_slug_fr", unique: true, where: "(slug_fr IS NOT NULL)"
    t.index ["city_id"], name: "index_neighborhoods_on_city_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.string "identifier", null: false
    t.integer "duration_months", null: false
    t.decimal "suggested_price", precision: 12, scale: 2
    t.string "currency", default: "mad", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.index ["active"], name: "index_plans_on_active"
    t.index ["identifier"], name: "index_plans_on_identifier", unique: true
  end

  create_table "provider_invoices", force: :cascade do |t|
    t.string "invoice_id", null: false
    t.bigint "subscription_id"
    t.decimal "total", precision: 10, scale: 2, null: false
    t.string "currency", default: "mad", null: false
    t.string "status", default: "pending", null: false
    t.string "payment_method"
    t.datetime "paid_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id", null: false
    t.index ["business_id"], name: "index_provider_invoices_on_business_id"
    t.index ["invoice_id"], name: "index_provider_invoices_on_invoice_id", unique: true
    t.index ["paid_at"], name: "index_provider_invoices_on_paid_at"
    t.index ["status"], name: "index_provider_invoices_on_status"
    t.index ["subscription_id"], name: "index_provider_invoices_on_subscription_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "booking_id"
    t.bigint "business_id", null: false
    t.bigint "user_id"
    t.integer "rating", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "response"
    t.datetime "responded_at"
    t.integer "cleanliness_rating"
    t.integer "punctuality_rating"
    t.integer "professionalism_rating"
    t.integer "service_quality_rating"
    t.integer "hygiene_rating"
    t.integer "ambiance_rating"
    t.integer "staff_friendliness_rating"
    t.integer "waiting_time_rating"
    t.integer "value_rating"
    t.jsonb "photos", default: []
    t.datetime "edited_at"
    t.string "moderation_status", default: "approved"
    t.text "moderation_notes"
    t.datetime "hidden_at"
    t.datetime "flagged_at"
    t.text "flag_reason"
    t.index ["booking_id"], name: "index_reviews_on_booking_id", unique: true
    t.index ["business_id", "moderation_status"], name: "index_reviews_on_business_id_and_moderation_status"
    t.index ["business_id"], name: "index_reviews_on_business_id"
    t.index ["moderation_status"], name: "index_reviews_on_moderation_status"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["responded_at"], name: "index_reviews_on_responded_at"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "seo_pages", force: :cascade do |t|
    t.string "path", null: false
    t.string "title"
    t.text "meta_description"
    t.text "seo_text"
    t.string "city"
    t.string "service"
    t.bigint "business_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_seo_pages_on_business_id"
    t.index ["city"], name: "index_seo_pages_on_city"
    t.index ["path"], name: "index_seo_pages_on_path", unique: true
    t.index ["service"], name: "index_seo_pages_on_service"
  end

  create_table "service_categories", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "color", default: "#3B82F6"
    t.integer "position", default: 0, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_service_categories_on_archived_at"
    t.index ["business_id", "position"], name: "index_service_categories_on_business_id_and_position"
    t.index ["business_id"], name: "index_service_categories_on_business_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "duration", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.string "image_url"
    t.bigint "category_id"
    t.string "name_en"
    t.string "name_fr"
    t.string "name_ar"
    t.text "description_en"
    t.text "description_fr"
    t.text "description_ar"
    t.string "image"
    t.bigint "service_category_id"
    t.index ["business_id"], name: "index_services_on_business_id"
    t.index ["category_id"], name: "index_services_on_category_id"
    t.index ["discarded_at"], name: "index_services_on_discarded_at"
    t.index ["name"], name: "index_services_on_name"
    t.index ["service_category_id"], name: "index_services_on_service_category_id"
  end

  create_table "staff_availabilities", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.boolean "available", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "user_id", "day_of_week"], name: "index_staff_availabilities_unique", unique: true
    t.index ["business_id"], name: "index_staff_availabilities_on_business_id"
    t.index ["user_id"], name: "index_staff_availabilities_on_user_id"
  end

  create_table "staff_services", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "staff_id", null: false
    t.bigint "service_id", null: false
    t.decimal "price_override", precision: 10, scale: 2
    t.integer "duration_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "staff_id", "service_id"], name: "idx_on_business_id_staff_id_service_id_905370b875", unique: true
    t.index ["service_id"], name: "index_staff_services_on_service_id"
    t.index ["staff_id"], name: "index_staff_services_on_staff_id"
  end

  create_table "staff_unavailabilities", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "user_id", "start_time"], name: "idx_on_business_id_user_id_start_time_d5205bed2b"
    t.index ["user_id"], name: "index_staff_unavailabilities_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "status", default: "active", null: false
    t.string "plan_id", default: "premium_monthly", null: false
    t.string "paid_via", default: "stripe", null: false
    t.datetime "started_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id", null: false
    t.index ["business_id"], name: "index_subscriptions_on_business_id"
    t.index ["expires_at"], name: "index_subscriptions_on_expires_at"
    t.index ["status"], name: "index_subscriptions_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "role", default: "customer", null: false
    t.string "encrypted_password", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_login_at"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "discarded_at"
    t.string "admin_role"
    t.string "locale", default: "en", null: false
    t.string "provider_status", default: "not_confirmed"
    t.string "oauth_provider"
    t.string "oauth_uid"
    t.string "first_name", null: false
    t.string "last_name"
    t.string "avatar"
    t.index ["admin_role"], name: "index_users_on_admin_role", where: "(admin_role IS NOT NULL)"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true, where: "(oauth_provider IS NOT NULL)"
    t.index ["provider_status"], name: "index_users_on_provider_status", where: "((role)::text = 'provider'::text)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_activity_logs", "users", column: "admin_user_id"
  add_foreign_key "booking_events", "bookings"
  add_foreign_key "booking_payments", "bookings"
  add_foreign_key "booking_payments", "users"
  add_foreign_key "booking_services", "bookings"
  add_foreign_key "booking_services", "services"
  add_foreign_key "booking_services", "users", column: "staff_id"
  add_foreign_key "bookings", "businesses"
  add_foreign_key "bookings", "users"
  add_foreign_key "bookings", "users", column: "staff_id"
  add_foreign_key "business_categories", "businesses"
  add_foreign_key "business_categories", "categories"
  add_foreign_key "business_claim_requests", "businesses"
  add_foreign_key "business_claim_requests", "users"
  add_foreign_key "business_search_indices", "businesses"
  add_foreign_key "business_search_indices", "categories"
  add_foreign_key "business_search_indices", "cities"
  add_foreign_key "business_staffs", "businesses"
  add_foreign_key "business_staffs", "users"
  add_foreign_key "business_statistics", "businesses", on_delete: :cascade
  add_foreign_key "businesses", "cities"
  add_foreign_key "businesses", "neighborhoods"
  add_foreign_key "businesses", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "clients", "businesses"
  add_foreign_key "clients", "users"
  add_foreign_key "neighborhoods", "cities"
  add_foreign_key "provider_invoices", "businesses"
  add_foreign_key "provider_invoices", "subscriptions"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "businesses"
  add_foreign_key "reviews", "users"
  add_foreign_key "seo_pages", "businesses"
  add_foreign_key "service_categories", "businesses"
  add_foreign_key "services", "businesses"
  add_foreign_key "services", "categories"
  add_foreign_key "services", "service_categories"
  add_foreign_key "staff_availabilities", "businesses"
  add_foreign_key "staff_availabilities", "users"
  add_foreign_key "staff_services", "businesses"
  add_foreign_key "staff_services", "services"
  add_foreign_key "staff_services", "users", column: "staff_id"
  add_foreign_key "staff_unavailabilities", "businesses"
  add_foreign_key "staff_unavailabilities", "users"
  add_foreign_key "subscriptions", "businesses"
end
