# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingPolicy do
  subject { described_class.new(user, booking) }

  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:provider) { create(:user, :provider) }
  let(:other_provider) { create(:user, :provider) }
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business) }
  let(:booking) { create(:booking, user: customer, service: service, business: business) }

  describe "#index?" do
    context "when user is present" do
      let(:user) { customer }

      it { is_expected.to permit_action(:index) }
    end

    context "when user is nil" do
      let(:user) { nil }

      it { is_expected.to forbid_action(:index) }
    end
  end

  describe "#show?" do
    context "as the booking owner (customer)" do
      let(:user) { customer }

      it { is_expected.to permit_action(:show) }
    end

    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_action(:show) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:show) }
    end

    context "as another customer" do
      let(:user) { other_customer }

      it { is_expected.to forbid_action(:show) }
    end

    context "as another provider" do
      let(:user) { other_provider }

      it { is_expected.to forbid_action(:show) }
    end
  end

  describe "#create?" do
    context "when user is present" do
      let(:user) { customer }

      it { is_expected.to permit_action(:create) }
    end

    context "when user is nil" do
      let(:user) { nil }

      it { is_expected.to forbid_action(:create) }
    end
  end

  describe "#update?" do
    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_action(:update) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:update) }
    end

    context "as the booking owner (customer)" do
      let(:user) { customer }

      it { is_expected.to forbid_action(:update) }
    end
  end

  describe "#destroy? / #cancel?" do
    context "as the booking owner" do
      let(:user) { customer }

      it { is_expected.to permit_actions(:destroy, :cancel) }
    end

    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_actions(:destroy, :cancel) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_actions(:destroy, :cancel) }
    end

    context "as another customer" do
      let(:user) { other_customer }

      it { is_expected.to forbid_actions(:destroy, :cancel) }
    end
  end

  describe "#confirm? / #complete?" do
    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_actions(:confirm, :complete) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_actions(:confirm, :complete) }
    end

    context "as the booking owner (customer)" do
      let(:user) { customer }

      it { is_expected.to forbid_actions(:confirm, :complete) }
    end
  end

  describe "Scope" do
    let!(:customer_booking) { create(:booking, user: customer, service: service, business: business) }
    let!(:other_business) { create(:business, user: other_provider) }
    let!(:other_service) { create(:service, business: other_business) }
    let!(:other_booking) { create(:booking, user: other_customer, service: other_service, business: other_business) }

    describe "for customer" do
      it "returns only their own bookings" do
        scope = described_class::Scope.new(customer, Booking).resolve

        expect(scope).to include(customer_booking)
        expect(scope).not_to include(other_booking)
      end
    end

    describe "for provider" do
      it "returns bookings from their business and their own bookings" do
        scope = described_class::Scope.new(provider, Booking).resolve

        expect(scope).to include(customer_booking) # booking in provider's business
        expect(scope).not_to include(other_booking)
      end
    end

    describe "for admin" do
      it "returns all bookings" do
        scope = described_class::Scope.new(admin, Booking).resolve

        expect(scope).to include(customer_booking, other_booking)
      end
    end
  end
end
