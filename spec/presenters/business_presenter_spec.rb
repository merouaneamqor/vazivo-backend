# frozen_string_literal: true

require "rails_helper"

RSpec.describe BusinessPresenter do
  subject(:presenter) { described_class.new(business) }

  let(:business) do
    create(:business,
           name: "Spa Oasis",
           description: "Relaxation and wellness",
           category: "Beauty & Wellness",
           address: "123 Main St",
           city: "Casablanca",
           lat: 33.5731,
           lng: -7.5898,
           phone: "+212 600 000 000",
           email: "spa@example.com",
           website: "https://spaoasis.com",
           opening_hours: {
             "monday" => { "open" => "09:00", "close" => "18:00" },
             "tuesday" => { "open" => "09:00", "close" => "18:00" },
           })
  end

  describe "#as_json" do
    let(:json) { presenter.as_json }

    it "includes basic attributes" do
      expect(json[:id]).to eq(business.id)
      expect(json[:slug]).to eq(business.slug)
      expect(json[:name]).to eq("Spa Oasis")
      expect(json[:description]).to eq("Relaxation and wellness")
      expect(json[:category]).to eq("Beauty & Wellness")
    end

    it "includes location attributes" do
      expect(json[:address]).to eq("123 Main St")
      expect(json[:city]).to eq("Casablanca")
      expect(json[:lat]).to eq(33.5731)
      expect(json[:lng]).to eq(-7.5898)
    end

    it "includes contact attributes" do
      expect(json[:phone]).to eq("+212 600 000 000")
      expect(json[:email]).to eq("spa@example.com")
      expect(json[:website]).to eq("https://spaoasis.com")
    end

    it "includes opening hours" do
      expect(json[:opening_hours]).to be_a(Hash)
      expect(json[:opening_hours]["monday"]).to eq({ "open" => "09:00", "close" => "18:00" })
    end

    it "includes computed attributes" do
      expect(json).to have_key(:average_rating)
      expect(json).to have_key(:total_reviews)
      expect(json).to have_key(:min_price)
      expect(json).to have_key(:max_price)
      expect(json).to have_key(:is_open)
    end

    it "includes timestamps" do
      expect(json[:created_at]).to be_present
    end
  end

  describe "#average_rating" do
    context "with no reviews" do
      it "returns 0" do
        expect(presenter.average_rating).to eq(0.0)
      end
    end

    context "with reviews" do
      let(:service) { create(:service, business: business) }
      let(:user) { create(:user, :customer) }

      before do
        booking1 = create(:booking, :completed, service: service, business: business, user: user)
        create(:review, booking: booking1, business: business, user: user, rating: 5)

        user2 = create(:user, :customer)
        booking2 = create(:booking, :completed, service: service, business: business, user: user2)
        create(:review, booking: booking2, business: business, user: user2, rating: 3)
      end

      it "returns the average" do
        expect(presenter.average_rating).to eq(4.0)
      end
    end
  end

  describe "#total_reviews" do
    context "with no reviews" do
      it "returns 0" do
        expect(presenter.total_reviews).to eq(0)
      end
    end

    context "with reviews" do
      let(:service) { create(:service, business: business) }
      let(:user) { create(:user, :customer) }

      before do
        booking = create(:booking, :completed, service: service, business: business, user: user)
        create(:review, booking: booking, business: business, user: user)
      end

      it "returns the count" do
        expect(presenter.total_reviews).to eq(1)
      end
    end
  end

  describe "#min_price / #max_price" do
    context "with no services" do
      it "returns nil" do
        expect(presenter.min_price).to be_nil
        expect(presenter.max_price).to be_nil
      end
    end

    context "with services" do
      before do
        create(:service, business: business, price: 50)
        create(:service, business: business, price: 150)
      end

      it "returns min and max prices" do
        expect(presenter.min_price).to eq(50)
        expect(presenter.max_price).to eq(150)
      end
    end
  end

  describe "#is_open?" do
    it "returns boolean based on current time" do
      expect(presenter.is_open?).to be_in([true, false])
    end
  end

  describe "#logo_url" do
    it "delegates to business.logo_url (nil when no logo or images)" do
      allow(business).to receive(:logo_url).and_return(nil)
      expect(presenter.logo_url).to be_nil
    end

    it "returns URL when business has logo" do
      allow(business).to receive(:logo_url).and_return("https://example.com/logo.jpg")
      expect(presenter.logo_url).to eq("https://example.com/logo.jpg")
    end
  end

  describe "#image_urls" do
    it "delegates to business.image_urls (empty when no images)" do
      allow(business).to receive(:image_urls).and_return([])
      expect(presenter.image_urls).to eq([])
    end

    it "returns URLs when business has images" do
      allow(business).to receive(:image_urls).and_return(["https://example.com/1.jpg", "https://example.com/2.jpg"])
      expect(presenter.image_urls).to eq(["https://example.com/1.jpg", "https://example.com/2.jpg"])
    end
  end
end
