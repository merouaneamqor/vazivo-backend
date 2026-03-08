# frozen_string_literal: true

require "rails_helper"

RSpec.describe Service, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:business) }
    it { is_expected.to have_many(:bookings).dependent(:destroy) }
    it { is_expected.to have_one_attached(:image) }
  end

  describe "validations" do
    subject { build(:service) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_presence_of(:duration) }
    it { is_expected.to validate_numericality_of(:duration).is_greater_than(0).is_less_than_or_equal_to(480) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let!(:cheap_service) { create(:service, price: 50, duration: 30) }
    let!(:expensive_service) { create(:service, price: 200, duration: 120) }
    let!(:discarded_service) { create(:service, :discarded) }

    describe ".active" do
      it "returns only non-discarded services" do
        expect(described_class.active).to include(cheap_service, expensive_service)
        expect(described_class.active).not_to include(discarded_service)
      end
    end

    describe ".by_price_range" do
      it "filters by price range" do
        expect(described_class.by_price_range(40, 100)).to include(cheap_service)
        expect(described_class.by_price_range(40, 100)).not_to include(expensive_service)
      end

      it "returns all when range is not provided" do
        expect(described_class.by_price_range(nil, nil)).to include(cheap_service, expensive_service)
      end
    end

    describe ".by_duration_range" do
      it "filters by duration range" do
        expect(described_class.by_duration_range(20, 60)).to include(cheap_service)
        expect(described_class.by_duration_range(20, 60)).not_to include(expensive_service)
      end
    end
  end

  describe "methods" do
    describe "#formatted_duration" do
      it "formats duration less than 60 minutes" do
        service = build(:service, duration: 45)
        expect(service.formatted_duration).to eq("45 min")
      end

      it "formats duration of exactly 60 minutes" do
        service = build(:service, duration: 60)
        expect(service.formatted_duration).to eq("1h")
      end

      it "formats duration greater than 60 minutes" do
        service = build(:service, duration: 90)
        expect(service.formatted_duration).to eq("1h 30min")
      end

      it "formats duration of exactly 2 hours" do
        service = build(:service, duration: 120)
        expect(service.formatted_duration).to eq("2h")
      end
    end

    describe "#formatted_price" do
      it "formats price with dollar sign" do
        service = build(:service, price: 50.5)
        currency = Rails.application.config.x.app_currency || "MAD"
        expect(service.formatted_price).to eq("50.5 #{currency}")
      end

      it "formats whole number prices" do
        service = build(:service, price: 100)
        currency = Rails.application.config.x.app_currency || "MAD"
        expect(service.formatted_price).to eq("100.0 #{currency}")
      end
    end

    describe "#upcoming_bookings" do
      let(:service) { create(:service) }
      let(:user) { create(:user, :customer) }

      it "returns upcoming bookings" do
        upcoming = create(:booking, :future, service: service, user: user)
        past = create(:booking, service: service, user: user, date: Date.yesterday)

        expect(service.upcoming_bookings).to include(upcoming)
        expect(service.upcoming_bookings).not_to include(past)
      end
    end

    describe "#available_on?" do
      let(:service) { create(:service) }

      it "delegates to AvailabilityService" do
        availability_service = instance_double(AvailabilityService)
        allow(AvailabilityService).to receive(:new).with(service).and_return(availability_service)
        allow(availability_service).to receive(:available?).with(Date.tomorrow, "10:00").and_return(true)

        expect(service.available_on?(Date.tomorrow, "10:00")).to be true
      end
    end
  end
end
