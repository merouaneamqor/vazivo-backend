# frozen_string_literal: true

require "rails_helper"

RSpec.describe Business, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:services).dependent(:destroy) }
    it { is_expected.to have_many(:bookings).dependent(:destroy) }
    it { is_expected.to have_many(:reviews).dependent(:destroy) }
    it { is_expected.to have_many_attached(:images) }
    it { is_expected.to have_one_attached(:logo) }
  end

  describe "validations" do
    subject { build(:business) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(200) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_presence_of(:city) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_numericality_of(:lat).allow_nil }
    it { is_expected.to validate_numericality_of(:lng).allow_nil }
  end

  describe "callbacks" do
    describe "#set_h3_index_from_coordinates" do
      it "sets h3_index when lat and lng are present" do
        business = create(:business, lat: 33.5, lng: -7.5)
        expect(business.h3_index).to be_present
        expect(business.h3_index).to match(/\A[0-9a-f]+\z/)
      end

      it "clears h3_index when lat is nil" do
        business = create(:business, lat: 33.5, lng: -7.5)
        business.update(lat: nil, lng: nil)
        expect(business.reload.h3_index).to be_nil
      end
    end

    describe "#generate_slug_if_needed" do
      it "generates a slug from name and city" do
        business = create(:business, name: "Spa Oasis", city: "Casablanca")
        expect(business.slug).to eq("spa-oasis-casablanca")
      end

      it "ensures slug uniqueness" do
        create(:business, name: "Spa Oasis", city: "Casablanca")
        business2 = create(:business, name: "Spa Oasis", city: "Casablanca")
        expect(business2.slug).to eq("spa-oasis-casablanca-1")
      end

      it "regenerates slug when name changes" do
        business = create(:business, name: "Old Name", city: "Casablanca")
        business.update(name: "New Name")
        expect(business.slug).to eq("new-name-casablanca")
      end

      it "regenerates slug when city changes" do
        business = create(:business, name: "Spa", city: "Casablanca")
        business.update(city: "Rabat")
        expect(business.slug).to eq("spa-rabat")
      end
    end
  end

  describe "scopes" do
    let!(:business1) { create(:business, name: "Spa Oasis", category: "Beauty & Wellness", city: "Casablanca") }
    let!(:business2) { create(:business, name: "Fitness Zone", category: "Fitness", city: "Rabat") }
    let!(:discarded) { create(:business, :discarded) }

    describe ".active" do
      it "returns only non-discarded businesses" do
        expect(described_class.active).to include(business1, business2)
        expect(described_class.active).not_to include(discarded)
      end
    end

    describe ".by_category" do
      it "filters by category (case insensitive)" do
        expect(described_class.by_category("beauty & wellness")).to include(business1)
        expect(described_class.by_category("beauty & wellness")).not_to include(business2)
      end

      it "returns all when category is blank" do
        expect(described_class.by_category(nil)).to include(business1, business2)
      end
    end

    describe ".by_city" do
      it "filters by city (case insensitive)" do
        expect(described_class.by_city("casablanca")).to include(business1)
        expect(described_class.by_city("casablanca")).not_to include(business2)
      end
    end

    describe ".search" do
      it "searches by name" do
        expect(described_class.search("spa")).to include(business1)
        expect(described_class.search("spa")).not_to include(business2)
      end

      it "searches by description" do
        business1.update(description: "Relaxation and wellness")
        expect(described_class.search("relaxation")).to include(business1)
      end
    end

    describe ".near" do
      it "returns businesses within H3 radius of the given lat/lng" do
        near_business = create(:business, name: "Near Spa", lat: 33.5, lng: -7.5, city: "Casablanca")
        far_business = create(:business, name: "Far Spa", lat: 48.8, lng: 2.3, city: "Paris")

        results = described_class.near(33.5, -7.5, 10)
        expect(results).to include(near_business)
        expect(results).not_to include(far_business)
      end

      it "returns none when lat or lng is missing" do
        create(:business, lat: 33.5, lng: -7.5)
        expect(described_class.near(nil, -7.5, 10)).to be_empty
        expect(described_class.near(33.5, nil, 10)).to be_empty
      end

      it "excludes businesses with nil h3_index" do
        business = create(:business, lat: 33.5, lng: -7.5)
        business.update_columns(lat: nil, lng: nil, h3_index: nil)
        results = described_class.near(33.5, -7.5, 10)
        expect(results).not_to include(business)
      end
    end
  end

  describe "methods" do
    let(:business) { create(:business, :with_services) }

    describe "#average_rating" do
      it "returns 0 when there are no reviews" do
        expect(business.average_rating).to eq(0.0)
      end

      it "returns the average rating" do
        service = business.services.first
        user = create(:user, :customer)

        booking1 = create(:booking, :completed, service: service, business: business, user: user)
        create(:review, booking: booking1, business: business, user: user, rating: 5)

        user2 = create(:user, :customer)
        booking2 = create(:booking, :completed, service: service, business: business, user: user2)
        create(:review, booking: booking2, business: business, user: user2, rating: 3)

        expect(business.average_rating).to eq(4.0)
      end
    end

    describe "#total_reviews" do
      it "returns the count of reviews" do
        expect(business.total_reviews).to eq(0)

        service = business.services.first
        user = create(:user, :customer)
        booking = create(:booking, :completed, service: service, business: business, user: user)
        create(:review, booking: booking, business: business, user: user)

        expect(business.reload.total_reviews).to eq(1)
      end
    end

    describe "#is_open?" do
      let(:business) do
        create(:business, opening_hours: {
          "monday" => { "open" => "09:00", "close" => "18:00" },
          "tuesday" => { "open" => "09:00", "close" => "18:00" },
          "sunday" => { "open" => nil, "close" => nil },
        })
      end

      it "returns true when business is open" do
        monday_10am = Time.zone.parse("2026-02-02 10:00") # Monday
        expect(business.is_open?(monday_10am)).to be true
      end

      it "returns false when business is closed" do
        monday_7pm = Time.zone.parse("2026-02-02 19:00") # Monday after hours
        expect(business.is_open?(monday_7pm)).to be false
      end

      it "returns false on closed days" do
        sunday = Time.zone.parse("2026-02-08 12:00") # Sunday
        expect(business.is_open?(sunday)).to be false
      end
    end

    describe "#today_hours" do
      it "returns the hours for today" do
        business = create(:business)
        day = Time.current.strftime("%A").downcase
        expect(business.today_hours).to eq(business.opening_hours[day])
      end
    end

    describe "#min_service_price" do
      it "returns the minimum price among active services" do
        service1 = business.services.first
        service1.update(price: 50)
        business.services.last.update(price: 100)

        expect(business.min_service_price).to eq(50)
      end
    end

    describe "#max_service_price" do
      it "returns the maximum price among active services" do
        business.services.first.update(price: 50)
        business.services.last.update(price: 100)

        expect(business.max_service_price).to eq(100)
      end
    end

    describe "#active_services" do
      it "returns only non-discarded services" do
        active_count = business.services.kept.count
        business.services.first.discard

        expect(business.active_services.count).to eq(active_count - 1)
      end
    end
  end
end
