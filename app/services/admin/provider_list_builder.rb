# frozen_string_literal: true

module Admin
  class ProviderListBuilder
    THIRTY_DAYS_AGO = 30.days.ago.freeze
    NO_SHOW_HIGH_THRESHOLD = 0.10
    REFUND_HIGH_THRESHOLD = 0.20
    SUSPICIOUS_RATING_DAYS = 7

    def initialize(business)
      @business = business
    end

    def call
      b = @business
      user = b.user

      # Owner identity
      owner_name = user&.name
      owner_email = user&.email
      owner_phone = user&.phone
      owner_user_id = b.user_id
      last_login_at = user&.last_login_at
      account_status = if user.nil?
                         "active"
                       else
                         (user.discarded? ? "suspended" : "active")
                       end

      # Health metrics
      bookings_scope = b.bookings
      total_bookings_30d = bookings_scope.where(date: THIRTY_DAYS_AGO..).count
      completed_or_no_show = bookings_scope.where(status: ["completed", "no_show"])
      total_settled = completed_or_no_show.count
      no_show_count = bookings_scope.where(status: "no_show").count
      no_show_rate = total_settled.positive? ? (no_show_count.to_f / total_settled) : 0.0
      all_non_pending = bookings_scope.where.not(status: "pending")
      cancel_count = bookings_scope.where(status: "cancelled").count
      cancellation_rate = all_non_pending.any? ? (cancel_count.to_f / all_non_pending.count) : 0.0
      last_booking = bookings_scope.order(date: :desc, start_time: :desc).limit(1).first
      last_booking_at = last_booking ? combine_date_time(last_booking.date, last_booking.start_time) : nil
      first_booking = bookings_scope.order(date: :asc).limit(1).first
      first_booking_at = first_booking ? combine_date_time(first_booking.date, first_booking.start_time) : nil

      total_reviews = b.reviews.count
      average_rating = b.average_rating.to_f

      # Onboarding
      has_services = b.services.kept.exists?
      has_cover_photos = b.logo.present? || b.gallery_images.present?
      has_opening_hours = b.opening_hours.present? && opening_hours_any?(b.opening_hours)
      has_staff = b.staff_members.exists?
      has_availability = b.staff_availabilities.exists?
      has_category = true
      has_geo = b.lat.present? && b.lng.present?

      onboarding_score = [has_services, has_cover_photos, has_opening_hours, has_staff, has_availability, has_category,
                          has_geo].count(true)

      # Staff
      staff_count = b.staff_members.count
      staff_with_availability_count = b.staff_availabilities.distinct.count(:user_id)

      # Location
      address = b.address
      map_link = b.lat.present? && b.lng.present? ? "https://www.google.com/maps?q=#{b.lat},#{b.lng}" : nil
      geo_validated = b.respond_to?(:geo_validated) ? b.geo_validated : (b.lat.present? && b.lng.present?)

      # Compliance flags
      suspicious_rating_pattern = total_reviews >= 5 && average_rating >= 4.9 && recent_reviews_all?(b)
      high_no_show = no_show_rate > NO_SHOW_HIGH_THRESHOLD
      high_refund_rate = compute_high_refund_rate?(b)
      duplicate_listing = duplicate_listing?(b)
      banned_user_linked = user&.discarded? || false
      missing_documents = false

      # Verification (use column if present)
      verification_status = b.respond_to?(:verification_status) ? (b.verification_status.presence || "pending") : "pending"

      {
        id: b.id,
        slug: b.slug,
        name: b.name,
        category: b.category,
        city: b.read_attribute(:city).presence || (b.city.respond_to?(:name) ? b.city.name : nil),
        address: address,
        status: b.discarded? ? "suspended" : "approved",
        verification_status: verification_status,
        owner_name: owner_name,
        owner_email: owner_email,
        owner_phone: owner_phone,
        owner_user_id: owner_user_id,
        owner_provider_status: user&.provider_status,
        owner_premium_expires_at: b.premium_expires_at&.iso8601,
        owner_subscriptions_count: b.subscriptions.count,
        last_login_at: last_login_at&.iso8601,
        account_status: account_status,
        average_rating: average_rating,
        total_reviews: total_reviews,
        total_bookings: Booking.where(business_id: b.id).count,
        total_bookings_30d: total_bookings_30d,
        no_show_rate: no_show_rate.round(4),
        cancellation_rate: cancellation_rate.round(4),
        last_booking_at: last_booking_at&.iso8601,
        first_booking_at: first_booking_at&.iso8601,
        onboarding_score: onboarding_score,
        has_services: has_services,
        has_cover_photos: has_cover_photos,
        has_opening_hours: has_opening_hours,
        has_staff: has_staff,
        has_availability: has_availability,
        has_category: has_category,
        has_geo: has_geo,
        staff_count: staff_count,
        staff_with_availability_count: staff_with_availability_count,
        map_link: map_link,
        geo_validated: geo_validated,
        suspicious_rating_pattern: suspicious_rating_pattern,
        high_no_show: high_no_show,
        high_refund_rate: high_refund_rate,
        duplicate_listing: duplicate_listing,
        banned_user_linked: banned_user_linked,
        missing_documents: missing_documents,
        total_services: b.services.kept.count,
        user_id: b.user_id,
        created_at: b.created_at&.iso8601,
      }
    end

    private

    def opening_hours_any?(hours)
      return false unless hours.is_a?(Hash)

      hours.values.any? do |h|
        h.is_a?(Hash) && (h["open"].present? || h[:open].present?)
      end
    end

    def combine_date_time(date, time)
      return nil unless date && time

      Time.zone.parse("#{date} #{time}")
    end

    def recent_reviews_all?(business)
      return false if business.reviews.count < 5

      min_created = SUSPICIOUS_RATING_DAYS.days.ago
      business.reviews.where(created_at: min_created..).count >= 5
    end

    def compute_high_refund_rate?(business)
      booking_ids = business.bookings.pluck(:id)
      return false if booking_ids.empty?

      payments = BookingPayment.where(booking_id: booking_ids)
      succeeded = payments.where(status: "succeeded").count
      refunded = payments.where(status: "refunded").count
      return false if succeeded.zero?

      (refunded.to_f / succeeded) > REFUND_HIGH_THRESHOLD
    end

    def duplicate_listing?(business)
      return false if !business.phone? && !business.email?

      base = Business.where.not(id: business.id)
      by_phone = business.phone? && base.exists?(phone: business.phone)
      by_email = business.email? && base.exists?(email: business.email)
      by_phone || by_email
    end
  end
end
