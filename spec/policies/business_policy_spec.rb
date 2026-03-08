# frozen_string_literal: true

require "rails_helper"

RSpec.describe BusinessPolicy do
  subject { described_class.new(user, business) }

  let(:customer) { create(:user, :customer) }
  let(:provider) { create(:user, :provider) }
  let(:other_provider) { create(:user, :provider) }
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, user: provider) }

  describe "#index?" do
    context "for any user" do
      let(:user) { nil }

      it { is_expected.to permit_action(:index) }
    end
  end

  describe "#show?" do
    context "for any user" do
      let(:user) { nil }

      it { is_expected.to permit_action(:show) }
    end
  end

  describe "#create?" do
    context "as a provider" do
      let(:user) { provider }

      it { is_expected.to permit_action(:create) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:create) }
    end

    context "as a customer" do
      let(:user) { customer }

      it { is_expected.to forbid_action(:create) }
    end

    context "without authentication" do
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

    context "as another provider" do
      let(:user) { other_provider }

      it { is_expected.to forbid_action(:update) }
    end

    context "as a customer" do
      let(:user) { customer }

      it { is_expected.to forbid_action(:update) }
    end
  end

  describe "#destroy?" do
    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_action(:destroy) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:destroy) }
    end

    context "as another provider" do
      let(:user) { other_provider }

      it { is_expected.to forbid_action(:destroy) }
    end
  end

  describe "#manage_services?" do
    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_action(:manage_services) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:manage_services) }
    end

    context "as another provider" do
      let(:user) { other_provider }

      it { is_expected.to forbid_action(:manage_services) }
    end
  end

  describe "#view_bookings?" do
    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to permit_action(:view_bookings) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:view_bookings) }
    end

    context "as another provider" do
      let(:user) { other_provider }

      it { is_expected.to forbid_action(:view_bookings) }
    end

    context "as a customer" do
      let(:user) { customer }

      it { is_expected.to forbid_action(:view_bookings) }
    end
  end

  describe "Scope" do
    let!(:active_business) { create(:business, user: provider) }
    let!(:other_active_business) { create(:business, user: other_provider) }
    let!(:discarded_business) { create(:business, :discarded, user: provider) }

    describe "for customer" do
      it "returns only active businesses" do
        scope = described_class::Scope.new(customer, Business).resolve

        expect(scope).to include(active_business, other_active_business)
        expect(scope).not_to include(discarded_business)
      end
    end

    describe "for provider" do
      it "returns only their own kept businesses (so dashboard stats/bookings never 403)" do
        scope = described_class::Scope.new(provider, Business).resolve

        expect(scope).to include(active_business)
        expect(scope).not_to include(other_active_business)
        expect(scope).not_to include(discarded_business)
      end
    end

    describe "for admin" do
      it "returns all businesses" do
        scope = described_class::Scope.new(admin, Business).resolve

        expect(scope).to include(active_business, other_active_business, discarded_business)
      end
    end
  end
end
