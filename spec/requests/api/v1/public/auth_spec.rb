# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Public::Auth", type: :request do
  let(:valid_user_params) do
    {
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
    }
  end

  describe "POST /api/v1/public/auth/register" do
    context "with valid params" do
      it "creates a new user and returns tokens" do
        expect do
          post "/api/v1/public/auth/register", params: { user: valid_user_params }
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["user"]).to be_present
        expect(json["access_token"]).to be_present
        expect(json["expires_in"]).to be_present
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        post "/api/v1/public/auth/register", params: { user: { email: "invalid" } }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "with duplicate email" do
      before { create(:user, email: valid_user_params[:email]) }

      it "returns error" do
        post "/api/v1/public/auth/register", params: { user: valid_user_params }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/public/auth/register_provider" do
    let(:provider_params) do
      valid_user_params.merge(
        role: "provider",
        business_name: "Test Business",
        business_category: "salon"
      )
    end

    context "with valid params" do
      it "creates provider user and business" do
        expect do
          post "/api/v1/public/auth/register_provider", params: { user: provider_params }
        end.to change(User, :count).by(1).and change(Business, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["user"]["role"]).to eq("provider")
        expect(json["business"]).to be_present
      end
    end
  end

  describe "POST /api/v1/public/auth/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns tokens" do
        post "/api/v1/public/auth/login", params: {
          user: { email: "test@example.com", password: "password123" },
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["access_token"]).to be_present
        expect(json["user"]["email"]).to eq("test@example.com")
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized" do
        post "/api/v1/public/auth/login", params: {
          user: { email: "test@example.com", password: "wrong" },
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with non-existent email" do
      it "returns unauthorized" do
        post "/api/v1/public/auth/login", params: {
          user: { email: "nonexistent@example.com", password: "password123" },
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/public/auth/logout" do
    let(:user) { create(:user) }
    let(:headers) { auth_headers_for(user) }

    it "returns success" do
      delete "/api/v1/public/auth/logout", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to be_present
    end
  end

  describe "GET /api/v1/public/auth/me" do
    let(:user) { create(:user) }
    let(:headers) { auth_headers_for(user) }

    context "with valid token" do
      it "returns current user" do
        get "/api/v1/public/auth/me", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["user"]["id"]).to eq(user.id)
      end
    end

    context "without token" do
      it "returns unauthorized" do
        get "/api/v1/public/auth/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/public/auth/forgot_password" do
    let!(:user) { create(:user, email: "test@example.com") }

    it "sends password reset email" do
      post "/api/v1/public/auth/forgot_password", params: { email: "test@example.com" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to be_present
    end

    it "returns success even for non-existent email" do
      post "/api/v1/public/auth/forgot_password", params: { email: "nonexistent@example.com" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/public/auth/reset_password" do
    let(:user) { create(:user) }
    let(:token) { user.send(:set_reset_password_token) }

    context "with valid token" do
      it "resets password" do
        post "/api/v1/public/auth/reset_password", params: {
          token: token,
          password: "newpassword123",
          password_confirmation: "newpassword123",
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid token" do
      it "returns error" do
        post "/api/v1/public/auth/reset_password", params: {
          token: "invalid",
          password: "newpassword123",
          password_confirmation: "newpassword123",
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
