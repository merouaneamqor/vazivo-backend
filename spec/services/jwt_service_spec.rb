# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  let(:user) { create(:user, role: "customer") }

  describe ".encode_access_token" do
    it "encodes a payload into a JWT" do
      payload = { user_id: user.id, role: user.role }
      token = described_class.encode_access_token(payload)

      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3) # JWT has 3 parts
    end

    it "includes expiration claim" do
      payload = { user_id: user.id }
      token = described_class.encode_access_token(payload)
      decoded = described_class.decode_access_token(token)

      expect(decoded[:exp]).to be_present
      expect(decoded[:exp]).to be > Time.current.to_i
    end
  end

  describe ".decode_access_token" do
    it "decodes a valid token" do
      payload = { user_id: user.id, role: user.role }
      token = described_class.encode_access_token(payload)
      decoded = described_class.decode_access_token(token)

      expect(decoded[:user_id]).to eq(user.id)
      expect(decoded[:role]).to eq(user.role)
    end

    it "raises ExpiredToken for expired tokens" do
      payload = { user_id: user.id, exp: 1.hour.ago.to_i }
      token = JWT.encode(payload, described_class.access_secret, "HS256")

      expect do
        described_class.decode_access_token(token)
      end.to raise_error(JwtService::ExpiredToken)
    end

    it "raises InvalidToken for malformed tokens" do
      expect do
        described_class.decode_access_token("invalid.token.here")
      end.to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken for tokens signed with wrong secret" do
      payload = { user_id: user.id, exp: 1.hour.from_now.to_i }
      token = JWT.encode(payload, "wrong_secret", "HS256")

      expect do
        described_class.decode_access_token(token)
      end.to raise_error(JwtService::InvalidToken)
    end
  end

  describe ".encode_refresh_token / .decode_refresh_token" do
    it "encodes and decodes refresh tokens" do
      payload = { user_id: user.id, token_type: "refresh" }
      token = described_class.encode_refresh_token(payload)
      decoded = described_class.decode_refresh_token(token)

      expect(decoded[:user_id]).to eq(user.id)
      expect(decoded[:token_type]).to eq("refresh")
    end

    it "uses different secret than access tokens" do
      payload = { user_id: user.id }
      refresh_token = described_class.encode_refresh_token(payload)

      # Should fail when trying to decode refresh token with access secret
      expect do
        described_class.decode_access_token(refresh_token)
      end.to raise_error(JwtService::InvalidToken)
    end
  end

  describe ".generate_tokens" do
    it "generates access and refresh tokens" do
      tokens = described_class.generate_tokens(user)

      expect(tokens[:access_token]).to be_present
      expect(tokens[:refresh_token]).to be_present
      expect(tokens[:expires_in]).to be_present
    end

    it "includes user_id and role in tokens" do
      tokens = described_class.generate_tokens(user)
      decoded_access = described_class.decode_access_token(tokens[:access_token])
      decoded_refresh = described_class.decode_refresh_token(tokens[:refresh_token])

      expect(decoded_access[:user_id]).to eq(user.id)
      expect(decoded_access[:role]).to eq(user.role)
      expect(decoded_refresh[:user_id]).to eq(user.id)
      expect(decoded_refresh[:token_type]).to eq("refresh")
    end
  end

  describe ".refresh_tokens" do
    it "generates new tokens from valid refresh token" do
      original_tokens = described_class.generate_tokens(user)
      new_tokens = described_class.refresh_tokens(original_tokens[:refresh_token])

      expect(new_tokens[:access_token]).to be_present
      expect(new_tokens[:refresh_token]).to be_present
      expect(new_tokens[:access_token]).not_to eq(original_tokens[:access_token])
    end

    it "raises InvalidToken when using access token as refresh" do
      tokens = described_class.generate_tokens(user)

      expect do
        described_class.refresh_tokens(tokens[:access_token])
      end.to raise_error(JwtService::InvalidToken, "Invalid token type")
    end

    it "raises InvalidToken when user not found" do
      tokens = described_class.generate_tokens(user)
      user.destroy

      expect do
        described_class.refresh_tokens(tokens[:refresh_token])
      end.to raise_error(JwtService::InvalidToken, "User not found")
    end
  end

  describe "configuration" do
    it "uses environment variable for access secret" do
      expect(described_class.access_secret).to be_present
    end

    it "uses environment variable for refresh secret" do
      expect(described_class.refresh_secret).to be_present
      expect(described_class.refresh_secret).not_to eq(described_class.access_secret)
    end
  end
end
