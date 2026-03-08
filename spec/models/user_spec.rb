# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:businesses).dependent(:destroy) }
    it { is_expected.to have_many(:bookings).dependent(:destroy) }
    it { is_expected.to have_many(:reviews).dependent(:destroy) }
    it { is_expected.to have_one_attached(:avatar) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_length_of(:password).is_at_least(6) }
    it { is_expected.to validate_inclusion_of(:role).in_array(["customer", "provider", "admin"]) }

    context "email format" do
      it "accepts valid email addresses" do
        valid_emails = ["user@example.com", "user.name@domain.org", "user+tag@test.co.uk"]
        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid
        end
      end

      it "rejects invalid email addresses" do
        invalid_emails = ["invalid", "no@domain", "@nodomain.com", "spaces in@email.com"]
        invalid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).not_to be_valid
        end
      end
    end

    context "phone format" do
      it "accepts valid phone numbers" do
        valid_phones = ["+1234567890", "+212 612-345-678", "0612345678"]
        valid_phones.each do |phone|
          user = build(:user, phone: phone)
          expect(user).to be_valid
        end
      end

      it "accepts blank phone" do
        user = build(:user, phone: nil)
        expect(user).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "#downcase_email" do
      it "downcases email before saving" do
        user = create(:user, email: "TEST@EXAMPLE.COM")
        expect(user.email).to eq("test@example.com")
      end
    end
  end

  describe "scopes" do
    let!(:customer) { create(:user, :customer) }
    let!(:provider) { create(:user, :provider) }
    let!(:admin) { create(:user, :admin) }
    let!(:discarded) { create(:user, :discarded) }

    describe ".active" do
      it "returns only non-discarded users" do
        expect(described_class.active).to include(customer, provider, admin)
        expect(described_class.active).not_to include(discarded)
      end
    end

    describe ".providers" do
      it "returns only providers" do
        expect(described_class.providers).to include(provider)
        expect(described_class.providers).not_to include(customer, admin)
      end
    end

    describe ".customers" do
      it "returns only customers" do
        expect(described_class.customers).to include(customer)
        expect(described_class.customers).not_to include(provider, admin)
      end
    end

    describe ".admins" do
      it "returns only admins" do
        expect(described_class.admins).to include(admin)
        expect(described_class.admins).not_to include(customer, provider)
      end
    end
  end

  describe "role helpers" do
    describe "#admin?" do
      it "returns true for admin users" do
        user = build(:user, :admin)
        expect(user.admin?).to be true
      end

      it "returns false for non-admin users" do
        user = build(:user, :customer)
        expect(user.admin?).to be false
      end
    end

    describe "#provider?" do
      it "returns true for provider users" do
        user = build(:user, :provider)
        expect(user.provider?).to be true
      end

      it "returns false for non-provider users" do
        user = build(:user, :customer)
        expect(user.provider?).to be false
      end
    end

    describe "#customer?" do
      it "returns true for customer users" do
        user = build(:user, :customer)
        expect(user.customer?).to be true
      end

      it "returns false for non-customer users" do
        user = build(:user, :provider)
        expect(user.customer?).to be false
      end
    end
  end

  describe "#can_manage_business?" do
    let(:provider) { create(:user, :provider) }
    let(:other_provider) { create(:user, :provider) }
    let(:admin) { create(:user, :admin) }
    let(:business) { create(:business, user: provider) }

    it "returns true for business owner" do
      expect(provider.can_manage_business?(business)).to be true
    end

    it "returns true for admin" do
      expect(admin.can_manage_business?(business)).to be true
    end

    it "returns false for other providers" do
      expect(other_provider.can_manage_business?(business)).to be false
    end
  end

  describe "password reset (Devise recoverable)" do
    let(:user) { create(:user) }

    describe "#send_reset_password_instructions" do
      it "sets reset_password_token and reset_password_sent_at" do
        expect { user.send_reset_password_instructions }.to(change { user.reload.reset_password_token })
        expect(user.reset_password_sent_at).to be_within(1.second).of(Time.current)
      end
    end

    describe ".reset_password_by_token" do
      let(:raw_token) do
        raw, hashed = Devise.token_generator.generate(described_class, :reset_password_token)
        user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
        raw
      end

      it "resets password with valid token" do
        result = described_class.reset_password_by_token(
          reset_password_token: raw_token,
          password: "newpassword",
          password_confirmation: "newpassword"
        )
        expect(result.errors).to be_empty
        expect(user.reload.valid_password?("newpassword")).to be true
      end

      it "returns user with errors for invalid token" do
        result = described_class.reset_password_by_token(
          reset_password_token: "invalid-token",
          password: "newpassword",
          password_confirmation: "newpassword"
        )
        expect(result.errors[:reset_password_token]).to be_any
      end
    end
  end

  describe "password authentication (Devise valid_password?)" do
    let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

    it "authenticates with correct password" do
      expect(user.valid_password?("password123")).to be true
    end

    it "fails to authenticate with incorrect password" do
      expect(user.valid_password?("wrongpassword")).to be false
    end
  end
end
