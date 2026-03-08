# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProviderUpgradeService do
  let(:user) { create(:user, role: "customer") }
  let(:business_params) do
    {
      name: "Test Salon",
      description: "A test salon",
      categories: ["Hair Salon"],
      address: "123 Test St",
      city: "Casablanca",
      country: "Morocco",
    }
  end

  describe "#call" do
    context "with valid params" do
      it "upgrades user to provider" do
        service = described_class.new(user)
        result = service.call(business_params: business_params)

        expect(result[:success]).to be true
        expect(user.reload.role).to eq("provider")
        expect(user.provider_status).to eq("not_confirmed")
      end

      it "creates a business" do
        service = described_class.new(user)
        result = service.call(business_params: business_params)

        expect(result[:business]).to be_present
        expect(result[:business].name).to eq("Test Salon")
        expect(result[:business].user_id).to eq(user.id)
      end

      it "generates new tokens" do
        service = described_class.new(user)
        result = service.call(business_params: business_params)

        expect(result[:tokens]).to be_present
        expect(result[:tokens][:access_token]).to be_present
      end
    end

    context "with invalid params" do
      it "returns errors for missing business name" do
        service = described_class.new(user)
        result = service.call(business_params: business_params.except(:name))

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end
  end
end
