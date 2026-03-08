# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  let(:service) { described_class.new }

  describe "#register" do
    let(:valid_params) do
      {
        name: "John Doe",
        email: "john@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "customer",
      }
    end

    context "with valid params" do
      it "creates a new user" do
        expect do
          service.register(valid_params)
        end.to change(User, :count).by(1)
      end

      it "returns success with user and tokens" do
        result = service.register(valid_params)

        expect(result[:success]).to be true
        expect(result[:user]).to be_a(User)
        expect(result[:tokens][:access_token]).to be_present
        expect(result[:tokens][:refresh_token]).to be_present
      end
    end

    context "with invalid params" do
      it "returns failure with errors for missing email" do
        result = service.register(valid_params.except(:email))

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Email can't be blank")
      end

      it "returns failure with errors for duplicate email" do
        create(:user, email: "john@example.com")
        result = service.register(valid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Email has already been taken")
      end

      it "returns failure with errors for short password" do
        result = service.register(valid_params.merge(password: "short", password_confirmation: "short"))

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Password is too short (minimum is 6 characters)")
      end
    end
  end

  describe "#login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns success with user and tokens" do
        result = service.login("test@example.com", "password123")

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:tokens][:access_token]).to be_present
      end

      it "updates last_login_at" do
        expect do
          service.login("test@example.com", "password123")
        end.to(change { user.reload.last_login_at })
      end
    end

    context "with invalid email" do
      it "returns failure" do
        result = service.login("nonexistent@example.com", "password123")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Invalid email or password")
      end
    end

    context "with invalid password" do
      it "returns failure" do
        result = service.login("test@example.com", "wrongpassword")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Invalid email or password")
      end
    end

    context "with discarded user" do
      before { user.discard }

      it "returns failure" do
        result = service.login("test@example.com", "password123")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Account has been deactivated")
      end
    end

    context "with case-insensitive email" do
      it "finds user with different case" do
        result = service.login("TEST@EXAMPLE.COM", "password123")

        expect(result[:success]).to be true
      end
    end
  end

  describe "#refresh" do
    let(:user) { create(:user) }
    let(:tokens) { JwtService.generate_tokens(user) }

    context "with valid refresh token" do
      it "returns new tokens" do
        result = service.refresh(tokens[:refresh_token])

        expect(result[:success]).to be true
        expect(result[:tokens][:access_token]).to be_present
        expect(result[:tokens][:refresh_token]).to be_present
      end
    end

    context "with invalid refresh token" do
      it "returns failure" do
        result = service.refresh("invalid_token")

        expect(result[:success]).to be false
        expect(result[:errors].first).to include("Invalid token")
      end
    end

    context "with expired refresh token" do
      it "returns failure" do
        payload = { user_id: user.id, role: user.role, token_type: "refresh", exp: 1.hour.ago.to_i }
        expired_token = JWT.encode(payload, JwtService.refresh_secret, "HS256")

        result = service.refresh(expired_token)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Refresh token has expired")
      end
    end
  end

  describe "#update_password" do
    let(:user) { create(:user, password: "oldpassword", password_confirmation: "oldpassword") }

    context "with correct current password" do
      it "updates the password" do
        result = service.update_password(user, "oldpassword", "newpassword", "newpassword")

        expect(result[:success]).to be true
        expect(user.reload.valid_password?("newpassword")).to be true
      end
    end

    context "with incorrect current password" do
      it "returns failure" do
        result = service.update_password(user, "wrongpassword", "newpassword", "newpassword")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Current password is incorrect")
      end
    end

    context "with mismatched confirmation" do
      it "returns failure" do
        result = service.update_password(user, "oldpassword", "newpassword", "different")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Password confirmation doesn't match Password")
      end
    end
  end

  describe "#request_password_reset" do
    let!(:user) { create(:user, email: "test@example.com") }

    context "with existing email" do
      it "generates password reset token (Devise send_reset_password_instructions)" do
        expect do
          service.request_password_reset("test@example.com")
        end.to(change { user.reload.reset_password_token })
      end

      it "returns success message" do
        result = service.request_password_reset("test@example.com")

        expect(result[:success]).to be true
        expect(result[:message]).to eq("Password reset instructions sent")
      end
    end

    context "with non-existing email" do
      it "returns success (to prevent enumeration)" do
        result = service.request_password_reset("nonexistent@example.com")

        expect(result[:success]).to be true
      end
    end
  end

  describe "#reset_password" do
    let(:user) { create(:user) }

    context "with valid token" do
      let(:raw_token) do
        raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
        user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
        raw
      end

      it "resets the password" do
        result = service.reset_password(raw_token, "newpassword", "newpassword")

        expect(result[:success]).to be true
        expect(user.reload.valid_password?("newpassword")).to be true
      end

      it "clears the reset token" do
        service.reset_password(raw_token, "newpassword", "newpassword")

        expect(user.reload.reset_password_token).to be_blank
      end
    end

    context "with invalid token" do
      it "returns failure" do
        result = service.reset_password("invalid_token", "newpassword", "newpassword")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Invalid or expired reset token")
      end
    end

    context "with expired token" do
      let(:raw_token) do
        raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
        user.update_columns(reset_password_token: hashed, reset_password_sent_at: 8.hours.ago)
        raw
      end

      it "returns failure" do
        result = service.reset_password(raw_token, "newpassword", "newpassword")

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Invalid or expired reset token")
      end
    end
  end
end
