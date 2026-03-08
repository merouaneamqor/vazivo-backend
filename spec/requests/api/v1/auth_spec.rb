# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      {
        user: {
          name: "John Doe",
          email: "john@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "customer",
        },
      }
    end

    context "with valid parameters" do
      it "creates a new user and returns tokens" do
        expect do
          post "/api/v1/auth/register", params: valid_params, as: :json
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:user][:email]).to eq("john@example.com")
        expect(json_response[:access_token]).to be_present
      end
    end

    context "with invalid parameters" do
      it "returns errors for missing email" do
        post "/api/v1/auth/register", params: { user: valid_params[:user].except(:email) }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("Email can't be blank")
      end

      it "returns errors for duplicate email" do
        create(:user, email: "john@example.com")
        post "/api/v1/auth/register", params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("Email has already been taken")
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns tokens and user data" do
        post "/api/v1/auth/login", params: { user: { email: "test@example.com", password: "password123" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:user][:email]).to eq("test@example.com")
        expect(json_response[:access_token]).to be_present
      end

      it "sets auth cookies" do
        post "/api/v1/auth/login", params: { user: { email: "test@example.com", password: "password123" } }, as: :json

        expect(response.cookies["access_token"]).to be_present
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized" do
        post "/api/v1/auth/login", params: { user: { email: "test@example.com", password: "wrongpassword" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq("Invalid email or password")
      end
    end

    context "with discarded user" do
      before { user.discard }

      it "returns unauthorized" do
        post "/api/v1/auth/login", params: { user: { email: "test@example.com", password: "password123" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:user) { create(:user) }

    context "when authenticated" do
      it "returns the current user" do
        get "/api/v1/auth/me", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:user][:id]).to eq(user.id)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/auth/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with expired token" do
      it "returns unauthorized" do
        get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{generate_expired_token(user)}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    let(:user) { create(:user) }

    it "clears auth cookies" do
      delete "/api/v1/auth/logout", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json_response[:message]).to eq("Logged out successfully")
    end
  end
end
