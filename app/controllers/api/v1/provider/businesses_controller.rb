# frozen_string_literal: true

module Api
  module V1
    module Provider
      class BusinessesController < BaseController
        include ProdDataLoadHelpers

        before_action :set_business,
                      only: [:show, :update, :destroy, :bookings, :stats, :staff, :invite_staff, :add_staff, :update_staff, :remove_staff,
                             :availabilities, :add_photos, :remove_photo]
        before_action :set_business_for_images, only: [:create_image, :destroy_image]

        # GET /api/v1/provider/businesses
        def index
          businesses = policy_scope(Business).includes(:services, :reviews)
          render json: { businesses: businesses.map { |b| BusinessPresenter.new(b).as_json } }
        end

        # GET /api/v1/provider/businesses/:id
        def show
          authorize @business
          render json: { business: BusinessPresenter.new(@business).as_json }
        end

        # POST /api/v1/provider/businesses
        def create
          business = current_user.businesses.build(business_params)
          authorize business

          if business.save
            render json: { business: BusinessPresenter.new(business).as_json }, status: :created
          else
            render json: { errors: business.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH/PUT /api/v1/provider/businesses/:id
        # Logo: set via business[logo] (file). Gallery (photos): use POST/DELETE .../photos.
        def update
          authorize @business

          permitted = business_params
          logo_file = permitted.delete(:logo)
          if logo_file.present? && !valid_image?(logo_file)
            return render json: { errors: ["Image must be PNG, JPEG or JPG and under 5 MB per file."] }, status: :unprocessable_entity
          end
          attach_logo(logo_file) if logo_file.present?
          attach_images(permitted.delete(:images)) if permitted.key?(:images)
          

          if @business.update(permitted)
            render json: { business: BusinessPresenter.new(@business).as_json }
          else
            render json: { errors: @business.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/provider/businesses/:id
        def destroy
          authorize @business
          @business.discard
          head :no_content
        end

        # GET /api/v1/provider/businesses/search
        def search
          businesses = policy_scope(Business)
          businesses = businesses.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
          render json: { businesses: businesses.map { |b| BusinessPresenter.new(b).as_json } }
        end

        # GET /api/v1/provider/businesses/:id/bookings
        def bookings
          authorize @business, :view_bookings?
          bookings = @business.bookings.includes(:user, :services, :staff, booking_service_items: :service).order(date: :desc, start_time: :desc)
          bookings = bookings.where(status: params[:status]) if params[:status].present?
          render json: { bookings: bookings.map { |b| BookingSerializer.new(b).as_json } }
        end

        # GET /api/v1/provider/businesses/:id/stats
        def stats
          authorize @business, :view_bookings?
          render json: {
            total_bookings: @business.bookings.count,
            pending_bookings: @business.bookings.pending.count,
            confirmed_bookings: @business.bookings.confirmed.count,
            completed_bookings: @business.bookings.completed.count,
            total_revenue: @business.bookings.completed.sum(:total_price),
            total_reviews: @business.reviews.count,
            average_rating: @business.average_rating,
          }
        end

        # GET /api/v1/provider/businesses/:id/staff
        def staff
          authorize @business, :manage_staff?
          staff_list = @business.business_staff.active.includes(:user).order(Arel.sql("CASE role WHEN 'owner' THEN 0 ELSE 1 END"))
          # If business has only one staff member, they are automatically the owner
          if staff_list.size == 1 && !staff_list.first.owner?
            staff_list.first.update!(role: "owner")
          end
          render json: {
            staff: staff_list.map { |bs|
              u = bs.user
              role = (staff_list.size == 1) ? "owner" : bs.role
              { id: u.id, name: u.name, email: u.email, role: role, active: bs.active }
            }
          }
        end

        # POST /api/v1/provider/businesses/:id/staff
        def invite_staff
          authorize @business, :manage_staff?
          email = (params[:email] || params.dig(:business, :email))&.to_s&.strip&.downcase
          return render json: { errors: ["Email is required"] }, status: :unprocessable_entity if email.blank?

          role = (params[:role] || params.dig(:business, :role))&.to_s&.strip&.downcase
          role = "staff" unless role.present? && %w[manager staff].include?(role)
          first = (params[:first_name] || params.dig(:business, :first_name))&.to_s&.strip
          last  = (params[:last_name] || params.dig(:business, :last_name))&.to_s&.strip
          name_param = (params[:name] || params.dig(:business, :name))&.to_s&.strip
          name = if first.present?
            [first, last].compact.join(" ")
          elsif name_param.present?
            name_param
          else
            email.split("@").first&.truncate(100) || "Staff"
          end

          user = ::User.kept.find_by("LOWER(email) = ?", email)
          created_user = false
          if user.nil?
            user = ::User.new(
              email: email,
              name: name,
              role: "customer",
              password: SecureRandom.hex(16)
            )
            unless user.save
              return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
            end
            created_user = true
          end

          bs = @business.business_staff.find_by(user_id: user.id)
          if bs
            bs.update!(role: role, active: true) unless bs.owner?
            staff_member = { id: user.id, first_name: user.first_name, last_name: user.last_name.to_s, name: user.name, email: user.email, role: bs.role, active: bs.active }
            return render json: { staff_member: staff_member, created_user: false, message: "Staff member updated" }, status: :ok
          end

          @business.business_staff.create!(user_id: user.id, role: role, active: true)
          staff_member = { id: user.id, first_name: user.first_name, last_name: user.last_name.to_s, name: user.name, email: user.email, role: role, active: true }
          render json: { staff_member: staff_member, created_user: created_user, message: "Staff member added" }, status: :ok
        end

        # POST /api/v1/provider/businesses/:id/staff/:user_id
        def add_staff
          authorize @business, :manage_staff?
          user = ::User.find(params[:user_id])
          @business.staff_members << user unless @business.staff_members.include?(user)
          render json: { message: "Staff member added" }, status: :ok
        end

        # PATCH /api/v1/provider/businesses/:id/staff/:user_id
        def update_staff
          authorize @business, :manage_staff?
          bs = @business.business_staff.find_by!(user_id: params[:user_id])
          role = (params[:role] || params.dig(:business, :role))&.to_s&.strip&.downcase
          unless role.present? && %w[manager staff].include?(role)
            return render json: { errors: ["Role must be manager or staff"] }, status: :unprocessable_entity
          end
          if bs.owner?
            return render json: { errors: ["Cannot change owner role"] }, status: :unprocessable_entity
          end
          if bs.update(role: role)
            render json: { message: "Staff member updated" }, status: :ok
          else
            render json: { errors: bs.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Staff member not found" }, status: :not_found
        end

        # DELETE /api/v1/provider/businesses/:id/staff/:user_id
        def remove_staff
          authorize @business, :manage_staff?
          user = ::User.find(params[:user_id])
          @business.staff_members.delete(user)
          # If only one staff member remains, they are automatically the owner
          remaining = @business.business_staff.reload.active
          if remaining.size == 1 && !remaining.first.owner?
            remaining.first.update!(role: "owner")
          end
          render json: { message: "Staff member removed" }, status: :ok
        end

        # GET /api/v1/provider/businesses/:id/availabilities
        def availabilities
          authorize @business
          render json: { availabilities: [] }
        end

        # POST /api/v1/provider/businesses/:id/photos — add gallery images (params[:images] array of files).
        # Validates with valid_image? (PNG/JPEG/JPG, ≤ 5 MB). Max 10 gallery images total; excess rejected with 422.
        def add_photos
          authorize @business
          files = Array(params[:images]).compact
          if files.empty?
            return render json: { errors: ["no images provided"] }, status: :unprocessable_entity
          end

          invalid = files.reject { |f| valid_image?(f) }
          unless invalid.empty?
            return render json: {
              errors: ["Image must be PNG, JPEG or JPG and under 5 MB per file."]
            }, status: :unprocessable_entity
          end

          existing_count = @business.images.attachments.size
          max_new = [10 - existing_count, 0].max
          error_message = nil
          if files.size > max_new
            error_message = "Only the first #{max_new} image(s) were uploaded; maximum 10 allowed."
            files = files.first(max_new)
          end

          folder = CloudinaryPathBuilder.business_gallery_folder(@business.id)
          uploaded = 0
          files.each do |f|
            next if f.blank?
            result = CloudinaryUploader.upload(f, folder: folder)
            if result&.dig(:secure_url)
              attach_remote_url(@business, result[:secure_url], attach_as_logo: false, attach_as_image: true)
              uploaded += 1
            end
          end

          if error_message
            return render json: { errors: [error_message], image_urls: @business.image_urls }, status: :unprocessable_entity
          end

          render json: { image_urls: @business.image_urls }
        end

        # DELETE /api/v1/provider/businesses/:id/photos — remove one image by URL (matches business.image_urls order)
        def remove_photo
          authorize @business
          photo_url = params[:photo_url].to_s.strip
          if photo_url.blank?
            return render json: { errors: ["photo_url is required"] }, status: :unprocessable_entity
          end
          urls = @business.image_urls
          idx = urls.index(photo_url)
          unless idx
            # Try matching with trailing slash or query params
            idx = urls.index { |u| u.to_s.split("?").first == photo_url.split("?").first }
          end
          if idx.nil?
            return render json: { errors: ["Photo not found"] }, status: :not_found
          end
          @business.images.attachments[idx].purge
          render json: { image_urls: @business.image_urls }
        end

        # POST /api/v1/provider/businesses/:business_id/images — new Cloudinary API
        def create_image
          authorize @business
          files = Array(params[:images]).compact
          if files.empty?
            return render json: { errors: ["no images provided"] }, status: :unprocessable_entity
          end

          invalid = files.reject { |f| valid_image?(f) }
          unless invalid.empty?
            return render json: {
              errors: ["Image must be PNG, JPEG or JPG and under 5 MB per file."]
            }, status: :unprocessable_entity
          end

          existing_count = @business.images.attachments.size
          max_new = [10 - existing_count, 0].max
          errors = []
          if files.size > max_new
            errors << "Only the first #{max_new} image(s) were uploaded; maximum 10 allowed."
            files = files.first(max_new)
          end

          folder = CloudinaryPathBuilder.business_gallery_folder(@business.id)
          uploaded_images = []
          files.each do |f|
            next if f.blank?
            result = CloudinaryUploader.upload(f, folder: folder)
            if result&.dig(:secure_url) && result&.dig(:public_id)
              attach_remote_url(@business, result[:secure_url], attach_as_logo: false, attach_as_image: true)
              uploaded_images << { url: result[:secure_url], public_id: result[:public_id] }
            end
          end

          render json: { images: uploaded_images, errors: errors.presence }
        end

        # DELETE /api/v1/provider/businesses/:business_id/images/:public_id — new Cloudinary API
        def destroy_image
          authorize @business
          public_id = params[:id]
          if public_id.blank?
            return render json: { errors: ["public_id is required"] }, status: :unprocessable_entity
          end

          # Find attachment by matching public_id in metadata or URL
          attachment = @business.images.attachments.find do |att|
            url = att.url rescue nil
            url && url.include?(public_id)
          end

          unless attachment
            return render json: { errors: ["Image not found"] }, status: :not_found
          end

          attachment.purge
          render json: { message: "Image deleted successfully" }
        end

        private

        ALLOWED_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/jpg].freeze
        MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024 # 5 MB

        def valid_image?(uploaded_file)
          return false if uploaded_file.blank?
          return false unless ALLOWED_IMAGE_CONTENT_TYPES.include?(uploaded_file.content_type.to_s.strip.downcase)
          size = uploaded_file.respond_to?(:size) ? uploaded_file.size : uploaded_file.tempfile&.size
          size.present? && size <= MAX_IMAGE_SIZE_BYTES
        end

        def set_business
          @business = current_user_businesses.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Business not found" }, status: :not_found
        end

        def set_business_for_images
          @business = current_user_businesses.find(params[:business_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Business not found" }, status: :not_found
        end

        def business_params
          params.require(:business).permit(
            :name, :description, :phone, :email, :website,
            :address, :city, :neighborhood, :postal_code,
            :latitude, :longitude, :category,
            :opening_hours, :closing_hours,
            :logo,
            :name_en, :name_fr, :name_ar,
            :description_en, :description_fr, :description_ar,
            :slug_en, :slug_fr, :slug_ar,
            images: []
          )
        end

        def attach_logo(file)
          return if file.blank?

          folder = CloudinaryPathBuilder.business_cover_folder(@business.id)
          result = CloudinaryUploader.upload(file, folder: folder)
          attach_logo_from_url(@business, result[:secure_url]) if result&.dig(:secure_url)
        end

        def attach_images(files)
          return if files.blank?

          folder = CloudinaryPathBuilder.business_gallery_folder(@business.id)
          urls = Array(files).filter_map do |f|
            next if f.blank?
            r = CloudinaryUploader.upload(f, folder: folder)
            r&.dig(:secure_url)
          end
          attach_images_from_urls(@business, urls) if urls.any?
        end
      end
    end
  end
end
