# frozen_string_literal: true

module Api
  module V1
    module Provider
      class SearchController < BaseController
        LIMIT_PER_GROUP = 8
        SHORTCUTS = [
          { id: "calendar", label: "Calendar", href: "/provider/calendar", icon: "calendar", category: "Navigation" },
          { id: "services", label: "Services", href: "/provider/services", icon: "briefcase", category: "Navigation" },
          { id: "add-service", label: "Add Service", href: "/provider/services/new", icon: "plus",
            category: "Actions" },
          { id: "customers", label: "Customers", href: "/provider/customers", icon: "users", category: "Navigation" },
          { id: "staff", label: "Staff", href: "/provider/staff", icon: "user", category: "Navigation" },
          { id: "add-staff", label: "Add Staff", href: "/provider/staff/new", icon: "plus", category: "Actions" },
          { id: "reviews", label: "Reviews", href: "/provider/reviews", icon: "star", category: "Navigation" },
          { id: "settings", label: "Settings", href: "/provider/settings", icon: "settings", category: "Settings" },
          { id: "business-settings", label: "Business Settings", href: "/provider/settings", icon: "settings",
            category: "Settings" },
          { id: "opening-hours", label: "Opening Hours", href: "/provider/settings?tab=hours", icon: "clock",
            category: "Settings" },
          { id: "gallery", label: "Gallery", href: "/provider/photos", icon: "image", category: "Navigation" },
          { id: "payments", label: "Payments", href: "/provider/invoices", icon: "credit-card",
            category: "Navigation" },
        ].freeze

        def index
          q = params[:q].to_s.strip
          query = q.downcase
          business_ids = current_user_businesses.select(:id)

          # Shortcuts: always run (even empty query) so palette can show "Popular" / suggestions
          shortcuts = search_shortcuts(query)

          # No search term: return only shortcuts (and optional popular suggestions)
          if query.length < 2
            return render json: {
              shortcuts: shortcuts,
              bookings: [],
              customers: [],
              services: [],
              staff: [],
              businesses: [],
              reviews: [],
            }
          end

          # Tokenize for multi-term: "john haircut" -> ["john", "haircut"]
          terms = query.split(/\s+/).compact_blank
          like_patterns = terms.map { |t| "%#{sanitize_sql_like(t.downcase)}%" }
          phone_digits = q.gsub(/\D/, "")

          results = {
            shortcuts: shortcuts,
            bookings: search_bookings(business_ids, query, like_patterns, phone_digits),
            customers: search_customers(business_ids, query, like_patterns, phone_digits),
            services: search_services(business_ids, query, like_patterns),
            staff: search_staff(business_ids, query, like_patterns),
            businesses: search_businesses(query),
            reviews: search_reviews(business_ids, query, like_patterns),
          }

          render json: results
        end

        private

        def search_shortcuts(query)
          return SHORTCUTS.dup if query.blank?

          SHORTCUTS.select do |s|
            s[:label].downcase.include?(query) ||
              s[:category].downcase.include?(query) ||
              s[:id].downcase.include?(query)
          end
        end

        def search_bookings(business_ids, _query, like_patterns, phone_digits)
          rel = build_booking_relation(business_ids)
          rel = apply_booking_search(rel, like_patterns, phone_digits)
          rel = rel.order(Arel.sql("CASE WHEN date >= CURRENT_DATE THEN 0 ELSE 1 END"), date: :desc, start_time: :desc)
          bookings = rel.limit(LIMIT_PER_GROUP)

          bookings.map { |b| serialize_booking(b) }
        end

        def build_booking_relation(business_ids)
          Booking.where(business_id: business_ids)
                 .left_joins(:user, :business)
                 .joins(:service)
                 .includes(:user, :service, :staff, :business)
        end

        def apply_booking_search(rel, like_patterns, phone_digits)
          return apply_phone_search(rel, phone_digits) if like_patterns.empty? && phone_digits.present? && phone_digits.length >= 3
          return rel if like_patterns.empty?

          conds = []
          binds = []
          like_patterns.each do |pat|
            conds << "(LOWER(bookings.short_booking_id) LIKE ? OR LOWER(COALESCE(users.name, '')) LIKE ? OR LOWER(COALESCE(bookings.customer_name, '')) LIKE ? OR COALESCE(users.phone, '') LIKE ? OR COALESCE(bookings.customer_phone, '') LIKE ? OR LOWER(services.name) LIKE ? OR LOWER(bookings.status) LIKE ? OR LOWER(businesses.name) LIKE ?)"
            8.times { binds << pat }
          end
          rel.where(conds.join(" OR "), *binds)
        end

        def apply_phone_search(rel, phone_digits)
          phone_like = "%#{phone_digits}%"
          rel.where("REPLACE(REPLACE(REPLACE(COALESCE(users.phone, bookings.customer_phone, ''), ' ', ''), '-', ''), '+', '') LIKE ?", phone_like)
        end

        def serialize_booking(b)
          start_dt = b.date.is_a?(Date) ? b.date.to_time + b.start_time.seconds_since_midnight : b.start_time
          {
            id: b.id,
            booking_number: b.short_booking_id,
            customer_name: b.user&.name || b.customer_name || "Guest",
            customer_phone: b.user&.phone.presence || b.customer_phone.to_s,
            service_name: b.service&.translated_name || "Unknown",
            staff_name: b.staff&.name || "Unassigned",
            business_name: b.business&.translated_name || "Unknown",
            start_time: start_dt.iso8601,
            status: b.status,
            price: b.total_price.to_f,
          }
          end
        end

        def search_customers(business_ids, _query, like_patterns, phone_digits)
          rel = ::User.joins(:bookings).where(bookings: { business_id: business_ids }).distinct

          if like_patterns.any?
            conds = like_patterns.map do
              "LOWER(users.name) LIKE ? OR users.phone LIKE ? OR LOWER(users.email) LIKE ?"
            end.join(" OR ")
            binds = like_patterns.flat_map { |p| [p, p, p] }
            rel = rel.where(conds, *binds)
          elsif phone_digits.present? && phone_digits.length >= 3
            phone_like = "%#{phone_digits}%"
            rel = rel.where(
              "REPLACE(REPLACE(REPLACE(COALESCE(users.phone,''), ' ', ''), '-', ''), '+', '') LIKE ?",
              phone_like
            )
          end

          customers = rel.limit(LIMIT_PER_GROUP)

          customers.map do |c|
            {
              id: c.id,
              name: c.name,
              phone: c.phone.to_s,
              email: c.email.to_s,
              total_bookings: c.bookings.where(business_id: business_ids).count,
            }
          end
        end

        def search_services(business_ids, _query, like_patterns)
          rel = Service.kept.where(business_id: business_ids).left_joins(:category, :business)
          if like_patterns.any?
            conds = like_patterns.map do
              "(LOWER(services.name) LIKE ? OR LOWER(services.description) LIKE ? OR LOWER(COALESCE(categories.name, '')) LIKE ? OR LOWER(businesses.name) LIKE ?)"
            end.join(" OR ")
            binds = like_patterns.flat_map { |p| [p, p, p, p] }
            rel = rel.where(conds, *binds)
          end
          services = rel.limit(LIMIT_PER_GROUP)

          services.map do |s|
            {
              id: s.id,
              name: s.translated_name,
              duration: s.duration,
              price: s.price.to_f,
              category: Category.translated_name_for(s.category_name),
              business_name: s.business&.translated_name || "Unknown",
            }
          end
        end

        def search_staff(business_ids, _query, like_patterns)
          rel = BusinessStaff
            .active
            .where(business_id: business_ids)
            .joins(:user)
            .includes(:user, :business)

          if like_patterns.any?
            conds = like_patterns.map do
              "LOWER(users.name) LIKE ? OR LOWER(users.email) LIKE ? OR LOWER(business_staffs.role) LIKE ? OR LOWER(businesses.name) LIKE ?"
            end.join(" OR ")
            binds = like_patterns.flat_map { |p| [p, p, p, p] }
            rel = rel.where(conds, *binds)
          end

          staff_records = rel.limit(LIMIT_PER_GROUP)

          staff_records.map do |bs|
            u = bs.user
            {
              id: u.id,
              name: u.name,
              email: u.email,
              role: bs.role.presence || "Staff",
              business_name: bs.business&.translated_name || "Unknown",
              avatar_url: nil,
              available_today: true,
            }
          end
        end

        def search_businesses(query)
          return [] unless current_user.can_access_admin?

          like = "%#{sanitize_sql_like(query)}%"
          Business.kept
            .where("LOWER(name) LIKE ? OR LOWER(city) LIKE ?", like, like)
            .limit(LIMIT_PER_GROUP)
            .map do |b|
              {
                id: b.id,
                name: b.translated_name,
                city: b.city.to_s,
                category: Category.translated_name_for(b.category).to_s,
                status: b.discarded? ? "closed" : "open",
              }
            end
        end

        def search_reviews(business_ids, _query, like_patterns)
          rel = Review
            .where(business_id: business_ids)
            .joins(:user)
            .includes(:user, :business)

          if like_patterns.any?
            conds = like_patterns.map do
              "LOWER(users.name) LIKE ? OR LOWER(reviews.comment) LIKE ? OR LOWER(businesses.name) LIKE ?"
            end.join(" OR ")
            binds = like_patterns.flat_map { |p| [p, p, p] }
            rel = rel.where(conds, *binds)
          end

          reviews = rel.order(created_at: :desc).limit(LIMIT_PER_GROUP)

          reviews.map do |r|
            {
              id: r.id,
              customer_name: r.user&.name || "Anonymous",
              rating: r.rating || 0,
              comment: r.comment.to_s,
              business_name: r.business&.translated_name || "Unknown",
              created_at: r.created_at&.iso8601,
            }
          end
        end

        def sanitize_sql_like(str)
          str.to_s.gsub(/[%_\\]/, "\\\\\\0")
        end
      end
    end
  end
end
