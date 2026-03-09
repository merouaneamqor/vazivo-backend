# frozen_string_literal: true

module Api
  module V1
    module Provider
      class ServicesController < BaseController
        before_action :authenticate_user!, except: [:index, :show, :availability]
        before_action :set_business, only: [:index, :create]
        before_action :set_service, only: [:show, :update, :destroy, :availability]

        # GET /api/v1/businesses/:business_id/services
        def index
          services = @business.services.kept.includes(category: :parent)

          # Apply filters
          services = services.by_price_range(params[:min_price], params[:max_price])

          render json: services, each_serializer: ServiceSerializer
        end

        # GET /api/v1/services/:id
        def show
          authorize @service
          render json: @service, serializer: ServiceDetailSerializer
        end

        # GET /api/v1/services/:id/availability
        def availability
          authorize @service

          date = params[:date] ? Date.parse(params[:date]) : Date.current
          end_date = params[:end_date] ? Date.parse(params[:end_date]) : date + 13.days

          availability_service = AvailabilityService.new(@service)

          if params[:date] && !params[:end_date]
            # Single day availability
            slots = availability_service.available_slots(date)
            render json: {
              date: date.to_s,
              service_id: @service.id,
              duration: @service.duration,
              slots: slots,
            }
          else
            # Calendar view
            calendar = availability_service.availability_calendar(date, end_date)
            render json: {
              service_id: @service.id,
              duration: @service.duration,
              calendar: calendar,
            }
          end
        end

        # POST /api/v1/businesses/:business_id/services
        def create
          @service = @business.services.new
          set_basic_attributes
          set_service_names
          set_service_descriptions

          validate_category!
          return if performed?

          authorize @service

          if @service.save
            enqueue_translation_if_needed
            render json: @service, serializer: ServiceSerializer, status: :created
          else
            render_errors(@service.errors.full_messages)
          end
        end

        # PATCH /api/v1/services/:id
        def update
          authorize @service

          update_basic_attributes
          update_service_names
          update_service_descriptions

          validate_category!
          return if performed?

          if @service.save
            render json: @service, serializer: ServiceSerializer
          else
            render_errors(@service.errors.full_messages)
          end
        end

        # DELETE /api/v1/services/:id
        def destroy
          authorize @service
          @service.discard
          head :no_content
        end

        private

        def set_business
          business_id = params[:business_id] || params[:legacy_business_id]
          @business = Business.kept.find(business_id)
        end

        def set_service
          @service = Service.find(params[:id])
        end

        def service_params
          params.require(:service).permit(
            :name, :description, :duration, :price, :image, :image_url, :category_id, :service_category_id,
            :name_en, :name_fr, :name_ar,
            :description_en, :description_fr, :description_ar
          )
        end

        def set_basic_attributes
          @service.category_id = params.dig(:service, :category_id)
          @service.service_category_id = params.dig(:service, :service_category_id)
          @service.duration = params.dig(:service, :duration) || 30
          @service.price = params.dig(:service, :price) || 0
        end

        def set_service_names
          name_en = params.dig(:service, :name_en) || params.dig(:service, :name)
          name_fr = params.dig(:service, :name_fr) || name_en
          name_ar = params.dig(:service, :name_ar) || name_en

          @service.write_attribute(:name, name_en)
          @service.write_attribute(:name_en, name_en)
          @service.write_attribute(:name_fr, name_fr)
          @service.write_attribute(:name_ar, name_ar)
          
          @name_needs_translation = (name_fr == name_en || name_ar == name_en)
        end

        def set_service_descriptions
          desc_en = params.dig(:service, :description_en) || params.dig(:service, :description) || generate_description(:en)
          desc_fr = params.dig(:service, :description_fr) || generate_description(:fr)
          desc_ar = params.dig(:service, :description_ar) || generate_description(:ar)

          @service.write_attribute(:description_en, desc_en)
          @service.write_attribute(:description_fr, desc_fr)
          @service.write_attribute(:description_ar, desc_ar)
          
          canonical_desc = desc_en.presence || desc_fr.presence || desc_ar.presence
          @service.write_attribute(:description, canonical_desc) if canonical_desc.present?
        end

        def generate_description(locale)
          name = @service.name_en || @service.name
          return nil if name.blank?

          category_name = @service.service_category_id ? ServiceCategory.find_by(id: @service.service_category_id)&.name : "beauty service"
          ai_service = OpenRouterService.new
          
          ai_service.generate_service_description(name, category_name, locale: locale) || default_description(name, locale)
        end

        def default_description(name, locale)
          case locale
          when :en then "Professional #{name} service."
          when :fr then "Service professionnel de #{name}."
          when :ar then "خدمة احترافية #{name}"
          end
        end

        def enqueue_translation_if_needed
          TranslateServiceJob.perform_later(@service.id) if @name_needs_translation
        end

        def update_basic_attributes
          @service.category_id = params.dig(:service, :category_id) if params.dig(:service, :category_id)
          @service.service_category_id = params.dig(:service, :service_category_id) if params.dig(:service, :service_category_id)
          @service.duration = params.dig(:service, :duration) if params.dig(:service, :duration)
          @service.price = params.dig(:service, :price) if params.dig(:service, :price)
        end

        def update_service_names
          if params.dig(:service, :name_en).present?
            update_localized_names
          elsif params.dig(:service, :name).present?
            update_canonical_name
          end
        end

        def update_localized_names
          name_en = params.dig(:service, :name_en)
          name_fr = params.dig(:service, :name_fr) || name_en
          name_ar = params.dig(:service, :name_ar) || name_en

          @service.write_attribute(:name, name_en)
          @service.write_attribute(:name_en, name_en)
          @service.write_attribute(:name_fr, name_fr)
          @service.write_attribute(:name_ar, name_ar)
        end

        def update_canonical_name
          name = params.dig(:service, :name)
          @service.write_attribute(:name, name)
          @service.write_attribute(:name_en, name)
          @service.write_attribute(:name_fr, name)
          @service.write_attribute(:name_ar, name)
        end

        def update_service_descriptions
          if any_localized_description_present?
            update_localized_descriptions
          elsif params.dig(:service, :description).present?
            update_canonical_description
          end
        end

        def any_localized_description_present?
          params.dig(:service, :description_en).present? ||
            params.dig(:service, :description_fr).present? ||
            params.dig(:service, :description_ar).present?
        end

        def update_localized_descriptions
          desc_en = params.dig(:service, :description_en)
          desc_fr = params.dig(:service, :description_fr)
          desc_ar = params.dig(:service, :description_ar)

          @service.write_attribute(:description_en, desc_en) if desc_en.present?
          @service.write_attribute(:description_fr, desc_fr) if desc_fr.present?
          @service.write_attribute(:description_ar, desc_ar) if desc_ar.present?
          
          canonical_desc = desc_en.presence || desc_fr.presence || desc_ar.presence
          @service.write_attribute(:description, canonical_desc) if canonical_desc.present?
        end

        def update_canonical_description
          desc = params.dig(:service, :description)
          @service.write_attribute(:description_en, desc)
          @service.write_attribute(:description_fr, desc)
          @service.write_attribute(:description_ar, desc)
          @service.write_attribute(:description, desc)
        end

        def validate_category!
          return unless validate_service_category
          return if @service.category_id.blank?

          validate_and_set_category
        end

        def validate_service_category
          if @service.service_category_id.blank?
            render_errors(["Service category is required"])
            return false
          end

          service_category = ServiceCategory.find_by(id: @service.service_category_id)
          if service_category.nil?
            render_errors(["Service category not found"])
            return false
          end

          true
        end

        def validate_and_set_category
          cat = Category.find_by(id: @service.category_id)
          render_errors(["Category not found"]) and return if cat.nil?
          render_errors(["Category must be a sub-category"]) and return unless cat.subact?

          auto_set_name_from_category(cat)
        end

        def auto_set_name_from_category(cat)
          return if @service.name?

          if @service.respond_to?(:name_en=)
            @service.name_en = cat.translated_name(:en)
            @service.name_fr = cat.translated_name(:fr)
            @service.name_ar = cat.translated_name(:ar)
          else
            @service.name = cat.name
          end
        end
      end
    end
  end
end
