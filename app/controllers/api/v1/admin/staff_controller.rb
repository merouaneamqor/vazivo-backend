# frozen_string_literal: true

module Api
  module V1
    module Admin
      class StaffController < BaseController
        def index
          staff = ::User.admins.kept
          staff = staff.where(admin_role: params[:role]) if params[:role].present?
          staff = staff.order(created_at: :desc)
          @pagy, staff = pagy(staff, items: params[:per_page] || 20)
          items = staff.map { |u| staff_item(u) }
          render json: { staff: items, meta: pagination_meta }
        end

        def create
          permitted = staff_create_params
          user = ::User.new(permitted.except(:admin_role).to_h)
          user.role = :admin
          user.admin_role = safe_admin_role(permitted[:admin_role])
          if user.save
            log_admin_action(:create, "User", user.id, details: { message: "Created admin staff ##{user.id}" })
            render json: { staff: staff_item(user), message: "Admin created" }, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          user = ::User.admins.kept.find(params[:id])
          permitted = staff_update_params
          user.assign_attributes(permitted) if permitted.present?
          user.save!
          log_admin_action(:update, "User", user.id, details: { message: "Updated admin staff ##{user.id}" }, update_resource: user)
          render json: { user: ::UserSerializer.new(user).as_json, staff: staff_item(user) }
        end

        def promote
          user = ::User.kept.find(params[:user_id])
          if user.role_admin?
            render json: { error: "User is already an admin" }, status: :unprocessable_content
            return
          end
          admin_role = ::User::ALLOWED_ADMIN_ROLES.include?(params[:admin_role].to_s) ? params[:admin_role] : "support"
          user.update!(role: :admin, admin_role: admin_role)
          log_admin_action(:promote, "User", user.id, details: { message: "Promoted user ##{user.id} to admin" })
          render json: { staff: staff_item(user), message: "User promoted to admin" }
        end

        def suspend
          user = ::User.admins.kept.find(params[:id])
          user.discard
          log_admin_action(:suspend, "User", user.id, details: { message: "Suspended staff ##{user.id}" })
          render json: { message: "Staff suspended" }
        end

        private

        def staff_create_params
          params.permit(:first_name, :last_name, :email, :password, :phone, :locale, :admin_role).tap do |p|
            p.require(:first_name)
            p.require(:email)
            p.require(:password)
          end
        end

        def staff_update_params
          permitted = params.permit(:first_name, :last_name, :email, :phone, :locale, :admin_role).to_h
          permitted = permitted.reject { |_, v| v.blank? }
          return {} if permitted.empty?
          permitted[:admin_role] = safe_admin_role(permitted[:admin_role]) if permitted.key?(:admin_role)
          permitted[:locale] = safe_locale(permitted[:locale]) if permitted.key?(:locale)
          permitted
        end

        def safe_admin_role(value)
          return "support" if value.blank?
          ::User::ALLOWED_ADMIN_ROLES.include?(value.to_s) ? value.to_s : "support"
        end

        def safe_locale(value)
          return "en" if value.blank?
          %w[en fr ar].include?(value.to_s) ? value.to_s : "en"
        end

        def staff_item(u)
          {
            id: u.id,
            first_name: u.first_name,
            last_name: u.last_name.to_s,
            name: u.name,
            email: u.email,
            phone: u.phone.to_s,
            locale: u.locale,
            admin_role: u.admin_role || "superadmin",
            created_at: u.created_at
          }
        end
      end
    end
  end
end
