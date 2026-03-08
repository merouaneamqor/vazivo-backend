# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewPolicy do
  subject { described_class.new(user, review) }

  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:provider) { create(:user, :provider) }
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business) }
  let(:booking) { create(:booking, :completed, user: customer, service: service, business: business) }
  let(:review) { create(:review, booking: booking, user: customer, business: business) }

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
    context "as the review owner" do
      let(:user) { customer }

      it { is_expected.to permit_action(:update) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:update) }
    end

    context "as another customer" do
      let(:user) { other_customer }

      it { is_expected.to forbid_action(:update) }
    end

    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to forbid_action(:update) }
    end
  end

  describe "#destroy?" do
    context "as the review owner" do
      let(:user) { customer }

      it { is_expected.to permit_action(:destroy) }
    end

    context "as an admin" do
      let(:user) { admin }

      it { is_expected.to permit_action(:destroy) }
    end

    context "as another customer" do
      let(:user) { other_customer }

      it { is_expected.to forbid_action(:destroy) }
    end

    context "as the business owner" do
      let(:user) { provider }

      it { is_expected.to forbid_action(:destroy) }
    end
  end
end
