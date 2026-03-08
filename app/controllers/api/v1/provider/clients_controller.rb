# frozen_string_literal: true

module Api
  module V1
    module Provider
      class ClientsController < BaseController
        before_action :set_business
        before_action :authorize_manage_clients
        before_action :set_client, only: [:show, :update]

        # GET /api/v1/provider/businesses/:business_id/clients
        def index
          clients = @business.clients
          clients = clients.search_by(params[:q]) if params[:q].present?
          clients = clients.order(created_at: :desc)
          per_page = [(params[:per_page] || 100).to_i, 200].min
          page = [params[:page].to_i, 0].max
          clients = clients.offset(per_page * page).limit(per_page)
          render json: { clients: clients.map { |c| client_json(c) } }
        end

        # POST /api/v1/provider/businesses/:business_id/clients
        def create
          client = @business.clients.build(client_params)
          if client.save
            render json: { client: client_json(client) }, status: :created
          else
            render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/provider/businesses/:business_id/clients/:id
        def show
          render json: { client: client_json(@client) }
        end

        # PATCH /api/v1/provider/businesses/:business_id/clients/:id
        def update
          if @client.update(client_params)
            render json: { client: client_json(@client) }
          else
            render json: { errors: @client.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_business
          @business = Business.kept.find(params[:business_id])
        end

        def authorize_manage_clients
          authorize @business, :manage_staff?
        end

        def set_client
          @client = @business.clients.find(params[:id])
        end

        def client_params
          params.require(:client).permit(:first_name, :last_name, :name, :phone, :email)
        end

        def client_json(client)
          {
            id: client.id,
            first_name: client.first_name,
            last_name: client.last_name.to_s,
            name: client.name,
            phone: client.phone.to_s,
            email: client.email.to_s,
            user_id: client.user_id,
            created_at: client.created_at&.iso8601,
          }
        end
      end
    end
  end
end
