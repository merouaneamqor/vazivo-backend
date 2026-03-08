# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewPresenter do
  subject(:presenter) { described_class.new(review) }

  let(:customer) { create(:user, :customer, name: "John Doe") }
  let(:business) { create(:business, :with_services) }
  let(:service) { business.services.first }
  let(:booking) { create(:booking, :completed, user: customer, service: service, business: business) }
  let(:review) do
    create(:review,
           booking: booking,
           user: customer,
           business: business,
           rating: 5,
           comment: "Excellent service!")
  end

  describe "#as_json" do
    let(:json) { presenter.as_json }

    it "includes basic attributes" do
      expect(json[:id]).to eq(review.id)
      expect(json[:rating]).to eq(5)
      expect(json[:comment]).to eq("Excellent service!")
    end

    it "includes user information" do
      expect(json[:user]).to be_a(Hash)
      expect(json[:user][:id]).to eq(customer.id)
      expect(json[:user][:name]).to eq("John Doe")
    end

    it "includes service information" do
      expect(json[:service_name]).to eq(service.name)
    end

    it "includes timestamps" do
      expect(json[:created_at]).to be_present
    end
  end

  describe "user initials" do
    let(:json) { presenter.as_json }

    it "includes user initials" do
      expect(json[:user][:initials]).to eq("JD")
    end

    context "with single name" do
      before { customer.update(name: "Madonna") }

      it "uses first two letters" do
        expect(json[:user][:initials]).to eq("MA")
      end
    end
  end

  describe "with nil comment" do
    before { review.update(comment: nil) }

    it "includes nil comment" do
      expect(presenter.as_json[:comment]).to be_nil
    end
  end
end
