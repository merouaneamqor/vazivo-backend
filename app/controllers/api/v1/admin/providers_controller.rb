# frozen_string_literal: true

module Api
  module V1
    module Admin
      class ProvidersController < BaseController
        skip_before_action :require_admin_role!, only: [:exit_impersonation]

        def index
          businesses = Business.left_joins(:user)
          businesses = apply_search(businesses, params[:q]) if params[:q].present?
          businesses = businesses.where(businesses: { category: params[:category] }) if params[:category].present?
          if params[:subcategory].present?
            businesses = businesses.where(businesses: { subcategory: params[:subcategory] })
          end
          businesses = businesses.where("LOWER(businesses.city) = ?", params[:city].downcase) if params[:city].present?
          businesses = businesses.where(discarded_at: nil) if params[:status] == "approved"
          businesses = businesses.where.not(discarded_at: nil) if params[:status] == "suspended"
          if params[:verification_status].present?
            businesses = businesses.where(verification_status: params[:verification_status])
          end
          if Business.column_names.include?("onboarding_score")
            businesses = apply_onboarding_filter(businesses, params[:onboarding])
            if params[:onboarding_min].present?
              businesses = businesses.where(businesses: { onboarding_score: (params[:onboarding_min]).. })
            end
          end
          if params[:created_after].present?
            businesses = businesses.where(businesses: { created_at: (params[:created_after]).. })
          end
          if params[:created_before].present?
            businesses = businesses.where(businesses: { created_at: ..(params[:created_before]) })
          end
          businesses = apply_last_booking_filter(businesses, params[:last_booking_after], params[:last_booking_before])
          businesses = apply_rating_filter(businesses, params[:min_rating], params[:max_rating])
          businesses = apply_premium_filter(businesses, params[:premium_status]) if params[:premium_status].present?
          businesses = apply_published_filter(businesses, params[:published]) if params[:published].present?
          businesses = businesses.where(geo_validated: true) if params[:geo_validated] == "yes"
          businesses = businesses.where(geo_validated: false) if params[:geo_validated] == "no"
          businesses = apply_has_services_filter(businesses, params[:has_services]) if params[:has_services].present?
          businesses = apply_has_bookings_filter(businesses, params[:has_bookings]) if params[:has_bookings].present?
          if params[:neighborhood].present?
            businesses = businesses.where("LOWER(businesses.neighborhood) ILIKE ?",
                                          "%#{params[:neighborhood].downcase}%")
          end
          businesses = businesses.distinct.order(apply_order(params[:order]))
          @pagy, businesses = pagy(businesses, items: params[:per_page] || 20)

          businesses = businesses.includes(:user, :services, :reviews, :bookings, :business_staff, :staff_members,
                                           :staff_availabilities)
          items = businesses.map { |b| ::Admin::ProviderListBuilder.new(b).call }
          @providers = items
          @meta = pagination_meta
          render :index
        end

        def show
          business = Business.includes(:user, :services, :reviews, :bookings, :business_staff, :staff_members,
                                       :staff_availabilities).find(params[:id])
          list_item = ::Admin::ProviderListBuilder.new(business).call
          detail = admin_provider_detail(business)
          edit_fields = {
            description: business.read_attribute(:description),
            phone: business.read_attribute(:phone),
            email: business.read_attribute(:email),
            website: business.read_attribute(:website),
            opening_hours: business.read_attribute(:opening_hours) || {},
            neighborhood: business.read_attribute(:neighborhood).presence || (business.neighborhood.respond_to?(:name) ? business.neighborhood&.name : nil),
            country: business.read_attribute(:country),
            category_ids: category_ids_from_denormalized(business),
            categories: categories_from_denormalized(business),
          }
          @provider = list_item.merge(detail).merge(edit_fields)
          render :show
        end

        def create
          user = User.kept.find(provider_params[:user_id])
          attrs = provider_update_attrs(nil)
          business = user.businesses.build(attrs)
          city_str = params.dig(:provider, :city).to_s.strip.presence
          business.write_attribute(:city, business.city&.name || city_str) if city_str.present?
          apply_categories_to_business(business)
          if business.save
            log_admin_action(:create, "Business", business.id,
                             details: { message: "Created provider/business ##{business.id}" })
            @provider = admin_provider_detail(business)
            render :create, status: :created
          else
            render_errors(business.errors.full_messages)
          end
        end

        def update
          business = Business.find(params[:id])
          attrs = provider_update_attrs(business)
          business.assign_attributes(attrs)
          city_str = params.dig(:provider, :city).to_s.strip.presence
          business.write_attribute(:city, business.city&.name || city_str) if city_str.present?
          apply_categories_to_business(business)
          if business.save
            details = { message: "Updated provider ##{business.id}" }
            log_admin_action(:update, "Business", business.id, details: details, update_resource: business)
            @provider = BusinessSerializer.new(business).as_json
            render :update
          else
            render_errors(business.errors.full_messages)
          end
        end

        def approve
          business = Business.find(params[:id])
          business.undiscard if business.discarded?
          business.user.update!(provider_status: "confirmed")
          ProviderMailer.provider_approved(business.user, business).deliver_later
          log_admin_action(:approve, "Business", business.id, details: { message: "Approved provider ##{business.id}" })
          @message = "Provider approved"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def unconfirm
          business = Business.find(params[:id])
          business.user.update!(provider_status: "not_confirmed")
          log_admin_action(:unconfirm, "Business", business.id,
                           details: { message: "Unconfirmed provider ##{business.id}" })
          @message = "Provider unconfirmed"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def reject
          business = Business.find(params[:id])
          log_admin_action(:reject, "Business", business.id, details: { message: "Rejected provider ##{business.id}" })
          @message = "Provider rejected"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def suspend
          business = Business.find(params[:id])
          business.discard
          log_admin_action(:suspend, "Business", business.id,
                           details: { message: "Suspended provider ##{business.id}" })
          @message = "Provider suspended"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def impersonate
          business = Business.find(params[:id])
          user = business.user
          tokens = JwtService.generate_tokens(user, impersonator: current_user)
          set_impersonation_cookies(tokens, user)
          log_admin_action(:impersonate, "Business", business.id,
                           details: { message: "Impersonating provider ##{business.id}" })
          render json: { message: "Impersonating provider", access_token: tokens[:access_token],
                         expires_in: tokens[:expires_in] }
        end

        def verify
          business = Business.find(params[:id])
          business.update!(verification_status: "verified")
          log_admin_action(:verify, "Business", business.id, details: { message: "Verified provider ##{business.id}" })
          @message = "Provider verified"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def unverify
          business = Business.find(params[:id])
          business.update!(verification_status: "pending")
          log_admin_action(:unverify, "Business", business.id,
                           details: { message: "Set provider ##{business.id} to pending verification" })
          @message = "Provider set to pending verification"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def reactivate
          business = Business.find(params[:id])
          business.undiscard if business.discarded?
          log_admin_action(:reactivate, "Business", business.id,
                           details: { message: "Reactivated provider ##{business.id}" })
          @message = "Provider reactivated"
          @provider = BusinessSerializer.new(business).as_json
          render :message_with_provider
        end

        def send_onboarding_email
          business = Business.find(params[:id])
          log_admin_action(:send_onboarding_email, "Business", business.id,
                           details: { message: "Sent onboarding email for provider ##{business.id}" })
          # Stub: enqueue job or no-op
          render json: { message: "Onboarding email sent" }
        end

        # POST /api/v1/admin/providers/:id/upgrade
        # Grants premium to the business (params[:id] is business id). Body: { plan_id: (optional), expires_at:, paid_via:, amount: (optional), note: (optional) }
        def upgrade
          business = Business.find(params[:id])
          user = business.user

          unless user&.provider?
            return render json: { error: "Business owner is not a provider" }, status: :unprocessable_content
          end

          plan_id = params[:plan_id].presence
          plan = plan_id.present? ? Plan.find_by(identifier: plan_id) : nil
          if plan_id.present? && plan.nil?
            return render json: { error: "Plan not found" }, status: :unprocessable_content
          end

          default_expires = plan ? plan.duration_months.months.from_now : 1.month.from_now
          expires_at = params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : default_expires
          paid_via = params[:paid_via].presence || "cash"
          amount = params[:amount].present? ? params[:amount].to_d : (plan&.suggested_price || 0)
          note = params[:note].presence
          effective_plan_id = plan_id.presence || "premium_monthly"

          result = ProviderPremiumUpgradeService.new.call(
            business: business,
            expires_at: expires_at,
            paid_via: paid_via,
            amount: amount,
            currency: "mad",
            plan_id: effective_plan_id,
            metadata: { admin_granted: true, admin_id: current_user.id, note: note }.compact
          )

          if result[:success]
            business.reload
            log_admin_action(:upgrade, "Business", business.id,
                             details: { message: "Upgraded provider ##{business.id} to premium" })
            render json: {
              message: "Business upgraded to premium",
              business_id: business.id,
              premium_expires_at: business.premium_expires_at&.iso8601,
              provider: BusinessSerializer.new(business).as_json,
            }
          else
            render json: { error: Array(result[:errors]).join(", ") }, status: :unprocessable_content
          end
        end

        def exit_impersonation
          # Get original admin ID
          admin_id = cookies[:original_admin_id]
          return render json: { error: "Not impersonating" }, status: :bad_request unless admin_id

          # Get admin user and generate new tokens
          admin = ::User.find_by(id: admin_id)
          return render json: { error: "Admin not found" }, status: :not_found unless admin

          tokens = JwtService.generate_tokens(admin)

          # Clear impersonation cookies and set admin cookies
          cookie_domain = Rails.env.production? ? ".vazivo.com" : nil
          cookie_options = {
            httponly: true,
            secure: Rails.env.production?,
            same_site: Rails.env.production? ? :none : :lax,
            domain: cookie_domain,
          }

          cookies[:access_token] =
            { **cookie_options, value: tokens[:access_token], expires: tokens[:expires_in].seconds.from_now }
          cookies[:refresh_token] = { **cookie_options, value: tokens[:refresh_token], expires: 7.days.from_now }
          cookies.delete(:impersonating, domain: cookie_domain)
          cookies.delete(:impersonated_user, domain: cookie_domain)
          cookies.delete(:original_admin_id, domain: cookie_domain)

          render json: { message: "Exited impersonation", access_token: tokens[:access_token] }
        end

        private

        def apply_search(relation, q)
          return relation if q.blank?

          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
          relation.where(
            "businesses.name ILIKE :q OR businesses.city ILIKE :q OR businesses.slug ILIKE :q OR businesses.phone ILIKE :q OR businesses.email ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
            q: pattern
          )
        end

        def apply_last_booking_filter(relation, after_date, before_date)
          return relation if after_date.blank? && before_date.blank?

          sub = Booking.select(:business_id).where("bookings.business_id = businesses.id")
          sub = sub.where(bookings: { date: after_date.. }) if after_date.present?
          sub = sub.where(bookings: { date: ..before_date }) if before_date.present?
          relation.where("EXISTS (?)", sub)
        end

        def apply_rating_filter(relation, min_rating, max_rating)
          return relation if min_rating.blank? && max_rating.blank?

          sub = relation.joins(:reviews).group("businesses.id")
          sub = sub.having("AVG(reviews.rating) >= ?", min_rating.to_f) if min_rating.present?
          sub = sub.having("AVG(reviews.rating) <= ?", max_rating.to_f) if max_rating.present?
          sub
        end

        def apply_onboarding_filter(relation, onboarding)
          return relation if onboarding.blank?

          if onboarding.to_s == "complete"
            relation.where(businesses: { onboarding_score: 6.. })
          elsif onboarding.to_s == "incomplete"
            relation.where(businesses: { onboarding_score: ...6 })
          else
            relation
          end
        end

        def apply_premium_filter(relation, premium_status)
          case premium_status.to_s
          when "active"
            relation.where("businesses.premium_expires_at > ?", Time.current)
          when "expired"
            relation.where("businesses.premium_expires_at IS NOT NULL AND businesses.premium_expires_at <= ?",
                           Time.current)
          when "never"
            relation.where(premium_expires_at: nil)
          else
            relation
          end
        end

        def apply_published_filter(relation, published)
          case published.to_s
          when "yes"
            relation.where.not(published_at: nil)
          when "no"
            relation.where(published_at: nil)
          else
            relation
          end
        end

        def apply_has_services_filter(relation, has_services)
          case has_services.to_s
          when "yes"
            relation.where("EXISTS (SELECT 1 FROM services WHERE services.business_id = businesses.id AND services.discarded_at IS NULL)")
          when "no"
            relation.where("NOT EXISTS (SELECT 1 FROM services WHERE services.business_id = businesses.id AND services.discarded_at IS NULL)")
          else
            relation
          end
        end

        def apply_has_bookings_filter(relation, has_bookings)
          case has_bookings.to_s
          when "yes"
            relation.where("EXISTS (SELECT 1 FROM bookings WHERE bookings.business_id = businesses.id)")
          when "no"
            relation.where("NOT EXISTS (SELECT 1 FROM bookings WHERE bookings.business_id = businesses.id)")
          else
            relation
          end
        end

        def apply_order(order_param)
          case order_param.to_s
          when "name"
            Arel.sql("LOWER(businesses.name) ASC")
          when "rating"
            Arel.sql("(SELECT AVG(r.rating) FROM reviews r WHERE r.business_id = businesses.id) DESC NULLS LAST")
          when "last_booking_at"
            Arel.sql("(SELECT MAX(b2.date) FROM bookings b2 WHERE b2.business_id = businesses.id) DESC NULLS LAST")
          else
            Arel.sql("businesses.created_at DESC")
          end
        end

        def provider_params
          days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
          opening_hours_permit = days.index_with { [{ open: [], close: [] }] }
          params.require(:provider).permit(
            :user_id, :name, :description, :category, :address, :city, :neighborhood, :country,
            :phone, :email, :website, :verification_status,
            categories: [],
            opening_hours: opening_hours_permit
          )
        end

        # Build update/create attributes: resolve :city (string) to city_id; strip :categories (handled in apply_categories_to_business).
        def provider_update_attrs(_business)
          permitted = provider_params.to_h.with_indifferent_access.except(:user_id)
          permitted.delete(:categories)
          city_str = permitted.delete(:city).to_s.strip.presence
          if city_str.present?
            city_record = City.where(
              "LOWER(COALESCE(name, name_en, '')) = :c OR LOWER(COALESCE(slug, slug_en, '')) = :c",
              c: city_str.downcase
            ).first
            permitted[:city_id] = city_record&.id
          end
          permitted
        end

        # Set only denormalized category/categories from params (no business_categories join).
        def apply_categories_to_business(business)
          raw = params.dig(:provider, :categories)
          raw = Array(params.dig(:provider, :category)).compact_blank if raw.blank? && params.dig(:provider,
                                                                                                  :category).present?
          ids = resolve_category_ids(raw)
          by_id = Category.where(id: ids).index_by(&:id)
          names = ids.filter_map { |id| by_id[id]&.name }
          first = names.first.presence || business.read_attribute(:category).presence || "Salon de Beauté"
          business.write_attribute(:category, first)
          business.write_attribute(:categories, names)
        end

        def category_ids_from_denormalized(business)
          names = categories_from_denormalized(business)
          resolve_category_ids(names)
        end

        def categories_from_denormalized(business)
          arr = Array(business.read_attribute(:categories)).compact
          arr.presence || [business.read_attribute(:category)].compact
        end

        def resolve_category_ids(category_params)
          return [] if category_params.blank?

          Array(category_params).compact_blank.filter_map do |val|
            id = val.to_i if val.to_s.match?(/\A\d+\z/)
            id = Category.find_by(id: id)&.id if id.present?
            id ||= Category.find_by_slug_any_locale(val.to_s.parameterize.presence)&.id
            id ||= Category.where("LOWER(name) = ? OR LOWER(name_en) = ?", val.to_s.downcase.strip,
                                  val.to_s.downcase.strip).first&.id
            id
          end.uniq
        end

        def admin_provider_detail(b)
          {
            status: b.discarded? ? "suspended" : "approved",
            owner: b.user ? UserSerializer.new(b.user).as_json : nil,
            services: b.services.kept.map do |s|
              { id: s.id, name: s.translated_name, price: s.price, duration: s.duration }
            end,
            total_bookings: Booking.where(business_id: b.id).count,
          }
        end

        def set_impersonation_cookies(tokens, user)
          cookie_domain = Rails.env.production? ? ".vazivo.com" : nil
          cookie_options = {
            httponly: true,
            secure: Rails.env.production?,
            same_site: Rails.env.production? ? :none : :lax,
            domain: cookie_domain,
          }

          cookies[:access_token] =
            { **cookie_options, value: tokens[:access_token], expires: tokens[:expires_in].seconds.from_now }
          cookies[:refresh_token] = { **cookie_options, value: tokens[:refresh_token], expires: 7.days.from_now }

          # Set impersonation markers
          cookies[:impersonating] = {
            value: "true",
            expires: tokens[:expires_in].seconds.from_now,
            httponly: false,
            domain: cookie_domain,
          }
          cookies[:impersonated_user] = {
            value: user.name,
            expires: tokens[:expires_in].seconds.from_now,
            httponly: false,
            domain: cookie_domain,
          }
          cookies[:original_admin_id] = {
            value: current_user.id.to_s,
            expires: tokens[:expires_in].seconds.from_now,
            httponly: true,
            domain: cookie_domain,
          }
        end
      end
    end
  end
end
