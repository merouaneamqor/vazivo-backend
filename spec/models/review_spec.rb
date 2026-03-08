# frozen_string_literal: true

require "rails_helper"

RSpec.describe Review, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:booking) }
    it { is_expected.to belong_to(:business) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:review, booking: booking) }

    let(:booking) { create(:booking, :completed) }

    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_inclusion_of(:rating).in_range(1..5) }
    it { is_expected.to validate_uniqueness_of(:booking_id).with_message("already has a review") }
    it { is_expected.to validate_length_of(:comment).is_at_most(2000) }

    describe "#booking_belongs_to_user" do
      let(:other_user) { create(:user, :customer) }

      it "is invalid when booking does not belong to user" do
        review = build(:review, booking: booking, user: other_user)
        expect(review).not_to be_valid
        expect(review.errors[:base]).to include("You can only review your own bookings")
      end
    end

    describe "#booking_is_completed" do
      let(:pending_booking) { create(:booking) }

      it "is invalid when booking is not completed" do
        review = build(:review, booking: pending_booking, user: pending_booking.user)
        expect(review).not_to be_valid
        expect(review.errors[:base]).to include("You can only review completed bookings")
      end
    end
  end

  describe "callbacks" do
    describe "#set_associations" do
      let(:booking) { create(:booking, :completed) }

      it "sets business and user from booking" do
        review = create(:review, booking: booking, business: nil, user: nil)
        expect(review.business_id).to eq(booking.business_id)
        expect(review.user_id).to eq(booking.user_id)
      end
    end
  end

  describe "scopes" do
    let(:booking1) { create(:booking, :completed) }
    let(:booking2) { create(:booking, :completed) }
    let!(:review1) { create(:review, booking: booking1, rating: 5, comment: "Great!", created_at: 1.day.ago) }
    let!(:review2) { create(:review, booking: booking2, rating: 3, comment: nil, created_at: 1.hour.ago) }

    describe ".recent" do
      it "orders by created_at desc" do
        expect(described_class.recent.first).to eq(review2)
        expect(described_class.recent.last).to eq(review1)
      end
    end

    describe ".by_rating" do
      it "filters by rating" do
        expect(described_class.by_rating(5)).to include(review1)
        expect(described_class.by_rating(5)).not_to include(review2)
      end

      it "returns all when rating is blank" do
        expect(described_class.by_rating(nil)).to include(review1, review2)
      end
    end

    describe ".with_comment" do
      it "returns reviews with comments" do
        expect(described_class.with_comment).to include(review1)
        expect(described_class.with_comment).not_to include(review2)
      end
    end
  end
end
