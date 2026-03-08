# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServicePresenter do
  subject(:presenter) { described_class.new(service) }

  let(:business) { create(:business, name: "Test Spa") }
  let(:service) do
    create(:service,
           business: business,
           name: "Relaxing Massage",
           description: "A relaxing full body massage",
           duration: 60,
           price: 100)
  end

  describe "#as_json" do
    let(:json) { presenter.as_json }

    it "includes basic attributes" do
      expect(json[:id]).to eq(service.id)
      expect(json[:name]).to eq("Relaxing Massage")
      expect(json[:description]).to eq("A relaxing full body massage")
      expect(json[:duration]).to eq(60)
      expect(json[:price]).to eq(100.0)
    end

    it "includes formatted attributes" do
      expect(json[:formatted_duration]).to eq("1h")
      currency = Rails.application.config.x.app_currency || "MAD"
      expect(json[:formatted_price]).to eq("100.0 #{currency}")
    end

    it "includes business reference" do
      expect(json[:business_id]).to eq(business.id)
      expect(json[:business_name]).to eq("Test Spa")
      expect(json[:business_slug]).to eq(business.slug)
    end
  end

  describe "formatted_duration" do
    context "with duration less than 60 minutes" do
      before { service.update(duration: 45) }

      it "formats as minutes" do
        expect(presenter.as_json[:formatted_duration]).to eq("45 min")
      end
    end

    context "with duration of 90 minutes" do
      before { service.update(duration: 90) }

      it "formats as hours and minutes" do
        expect(presenter.as_json[:formatted_duration]).to eq("1h 30min")
      end
    end

    context "with duration of exactly 2 hours" do
      before { service.update(duration: 120) }

      it "formats as hours only" do
        expect(presenter.as_json[:formatted_duration]).to eq("2h")
      end
    end
  end
end
