# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UsersController < BaseController
        def index
          authorize ::User
          users = if params[:exclude_role].present?
                    ::User.kept.where.not(role: params[:exclude_role])
                  elsif params[:role].present?
                    ::User.kept.where(role: params[:role])
                  else
                    ::User.customers.kept
                  end
          if params[:q].present?
            users = users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%",
                                "%#{params[:q]}%")
          end
          users = users.order(created_at: :desc)
          @pagy, users = pagy(users, items: params[:per_page] || 20)

          items = users.map { |u| user_list_item(u) }
          render json: { users: items, meta: pagination_meta }
        end

        def show
          user = ::User.kept.find(params[:id])
          authorize user
          render json: { user: admin_user_detail(user) }
        end

        def update
          user = ::User.kept.find(params[:id])
          authorize user
          if user.update(user_params)
            log_admin_action(:update, "User", user.id, details: { message: "Updated user ##{user.id}" }, update_resource: user)
            render json: { user: ::UserSerializer.new(user).as_json }
          else
            render_errors(user.errors.full_messages)
          end
        end

        def destroy
          user = ::User.kept.find(params[:id])
          authorize user
          user.discard
          log_admin_action(:destroy, "User", user.id, details: { message: "Deleted user ##{user.id}" })
          render json: { message: "User deleted" }, status: :ok
        end

        def suspend
          user = ::User.kept.find(params[:id])
          authorize user, :destroy?
          user.discard
          log_admin_action(:suspend, "User", user.id, details: { message: "Suspended user ##{user.id}" })
          render json: { message: "User suspended", user: ::UserSerializer.new(user).as_json }
        end

        def unsuspend
          user = ::User.discarded.find(params[:id])
          user.undiscard
          log_admin_action(:unsuspend, "User", user.id, details: { message: "Unsuspended user ##{user.id}" })
          render json: { message: "User unsuspended", user: ::UserSerializer.new(user).as_json }
        end

        def force_password_reset
          user = ::User.kept.find(params[:id])
          user.send_reset_password_instructions
          log_admin_action(:force_password_reset, "User", user.id, details: { message: "Sent password reset to user ##{user.id}" })
          render json: { message: "Password reset instructions sent" }
        end

        private

        def user_params
          params.require(:user).permit(:first_name, :last_name, :name, :email, :phone, :role)
        end

        def user_list_item(u)
          {
            id: u.id,
            first_name: u.first_name,
            last_name: u.last_name.to_s,
            name: u.name,
            email: u.email,
            phone: u.phone,
            role: u.role,
            status: u.discarded? ? "suspended" : "active",
            total_bookings: u.bookings.count,
            total_reviews: u.reviews.count,
            last_login_at: u.try(:last_login_at),
            created_at: u.created_at,
          }
        end

        def admin_user_detail(u)
          ::UserSerializer.new(u).as_json.merge(
            phone: u.phone,
            status: u.discarded? ? "suspended" : "active",
            total_bookings: u.bookings.count,
            total_reviews: u.reviews.count,
            last_login_at: u.try(:last_login_at),
            bookings: u.bookings.includes(:business, booking_service_items: :service).limit(20).map do |b|
              primary_item = b.booking_service_items.first
              {
                id: b.id,
                date: b.date,
                status: b.status,
                service_name: primary_item&.service&.translated_name,
                business_name: b.business&.translated_name,
              }
            end,
            reviews: u.reviews.includes(:business).limit(20).map do |r|
              { id: r.id, rating: r.rating, business_name: r.business&.translated_name, created_at: r.created_at }
            end
          )
        end
      end
    end
  end
end
