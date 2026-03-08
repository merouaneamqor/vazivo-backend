# frozen_string_literal: true

require "rails_helper"

RSpec.describe Booking, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:service) }
    it { is_expected.to belong_to(:business) }
    it { is_expected.to have_one(:review).dependent(:destroy) }
    it { is_expected.to have_one(:booking_payment).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:booking) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:start_time) }
    it { is_expected.to validate_presence_of(:end_time) }

    it {
      expect(subject).to validate_inclusion_of(:status).in_array(["pending", "confirmed", "cancelled", "completed",
                                                                  "no_show"])
    }

    it { is_expected.to validate_numericality_of(:total_price).is_greater_than_or_equal_to(0).allow_nil }

    describe "custom validations" do
      describe "#end_time_after_start_time" do
        it "is invalid when end_time is before start_time" do
          booking = build(:booking)
          booking.end_time = booking.start_time - 1.hour
          expect(booking).not_to be_valid
          expect(booking.errors[:end_time]).to include("must be after start time")
        end
      end

      describe "#no_overlapping_bookings" do
        let(:service) { create(:service, duration: 60) }
        let(:user) { create(:user, :customer) }
        let!(:existing_booking) do
          create(:booking, service: service, user: user, date: Date.tomorrow, start_time: "10:00")
        end

        it "is invalid when overlapping with another booking" do
          overlapping = build(:booking, service: service, date: Date.tomorrow, start_time: "10:30")
          expect(overlapping).not_to be_valid
          expect(overlapping.errors[:base]).to include("This time slot is already booked")
        end

        it "is valid when not overlapping" do
          non_overlapping = build(:booking, service: service, date: Date.tomorrow, start_time: "11:30")
          expect(non_overlapping).to be_valid
        end
      end

      describe "#booking_within_business_hours" do
        let(:business) do
          create(:business, opening_hours: {
            "monday" => { "open" => "09:00", "close" => "18:00" },
            "sunday" => { "open" => nil, "close" => nil },
          })
        end
        let(:service) { create(:service, business: business, duration: 60) }

        it "is invalid when booking is outside business hours" do
          # Find a Monday
          monday = Time.zone.today.beginning_of_week(:monday)
          monday += 7 if monday <= Time.zone.today

          booking = build(:booking, service: service, date: monday, start_time: "07:00")
          expect(booking).not_to be_valid
          expect(booking.errors[:base]).to include("Booking time is outside business hours")
        end

        it "is invalid when business is closed" do
          # Find a Sunday
          sunday = Time.zone.today.end_of_week
          sunday += 7 if sunday <= Time.zone.today

          booking = build(:booking, service: service, date: sunday, start_time: "10:00")
          expect(booking).not_to be_valid
          expect(booking.errors[:base]).to include("Business is closed on this day")
        end
      end

      describe "#booking_in_future" do
        it "is invalid when date is in the past" do
          booking = build(:booking, date: Date.yesterday)
          expect(booking).not_to be_valid
          expect(booking.errors[:date]).to include("must be in the future")
        end
      end
    end
  end

  describe "callbacks" do
    describe "#set_business_from_service" do
      it "sets business from service" do
        service = create(:service)
        booking = create(:booking, service: service, business: nil)
        expect(booking.business_id).to eq(service.business_id)
      end
    end

    describe "#calculate_end_time" do
      it "calculates end time from start time and service duration" do
        service = create(:service, duration: 60)
        booking = create(:booking, service: service, start_time: "10:00", end_time: nil)
        expect(booking.end_time.strftime("%H:%M")).to eq("11:00")
      end
    end

    describe "#set_total_price" do
      it "sets total price from service price" do
        service = create(:service, price: 100)
        booking = create(:booking, service: service, total_price: nil)
        expect(booking.total_price).to eq(100)
      end
    end
  end

  describe "scopes" do
    let(:user) { create(:user, :customer) }
    let(:service) { create(:service) }
    let!(:upcoming_booking) { create(:booking, :future, user: user, service: service) }
    let!(:past_booking) do
      booking = build(:booking, user: user, service: service, date: Date.yesterday)
      booking.save(validate: false)
      booking
    end
    let!(:cancelled_booking) { create(:booking, :cancelled, :future, user: user, service: service) }

    describe ".upcoming" do
      it "returns upcoming non-cancelled bookings" do
        expect(described_class.upcoming).to include(upcoming_booking)
        expect(described_class.upcoming).not_to include(past_booking, cancelled_booking)
      end
    end

    describe ".past" do
      it "returns past bookings" do
        expect(described_class.past).to include(past_booking)
        expect(described_class.past).not_to include(upcoming_booking)
      end
    end

    describe ".active" do
      it "excludes cancelled and no_show bookings" do
        expect(described_class.active).to include(upcoming_booking)
        expect(described_class.active).not_to include(cancelled_booking)
      end
    end

    describe ".for_business" do
      it "returns bookings for a specific business" do
        expect(described_class.for_business(service.business_id)).to include(upcoming_booking)
      end
    end

    describe ".for_date" do
      it "returns bookings for a specific date" do
        expect(described_class.for_date(upcoming_booking.date)).to include(upcoming_booking)
      end
    end
  end

  describe "status methods" do
    let(:pending_booking) { build(:booking, status: "pending") }
    let(:confirmed_booking) { build(:booking, :confirmed) }
    let(:completed_booking) { build(:booking, :completed) }
    let(:cancelled_booking) { build(:booking, :cancelled) }

    describe "#can_cancel?" do
      it "returns true for pending bookings" do
        expect(pending_booking.can_cancel?).to be true
      end

      it "returns true for confirmed bookings" do
        expect(confirmed_booking.can_cancel?).to be true
      end

      it "returns false for completed bookings" do
        expect(completed_booking.can_cancel?).to be false
      end

      it "returns false for past bookings" do
        pending_booking.date = Date.yesterday
        expect(pending_booking.can_cancel?).to be false
      end
    end

    describe "#can_confirm?" do
      it "returns true for pending bookings" do
        expect(pending_booking.can_confirm?).to be true
      end

      it "returns false for non-pending bookings" do
        expect(confirmed_booking.can_confirm?).to be false
      end
    end

    describe "#can_complete?" do
      it "returns true for confirmed bookings on or before today" do
        confirmed_booking.date = Date.current
        expect(confirmed_booking.can_complete?).to be true
      end

      it "returns false for future bookings" do
        confirmed_booking.date = Date.tomorrow
        expect(confirmed_booking.can_complete?).to be false
      end

      it "returns false for non-confirmed bookings" do
        expect(pending_booking.can_complete?).to be false
      end
    end
  end

  describe "status transition methods" do
    let(:booking) { create(:booking) }

    describe "#cancel!" do
      it "cancels a cancellable booking" do
        expect(booking.cancel!).to be true
        expect(booking.reload.status).to eq("cancelled")
        expect(booking.cancelled_at).to be_present
      end

      it "returns false for non-cancellable bookings" do
        booking.update_column(:status, "completed")
        expect(booking.cancel!).to be false
      end
    end

    describe "#confirm!" do
      it "confirms a pending booking" do
        expect(booking.confirm!).to be true
        expect(booking.reload.status).to eq("confirmed")
        expect(booking.confirmed_at).to be_present
      end

      it "returns false for non-pending bookings" do
        booking.update_column(:status, "confirmed")
        expect(booking.confirm!).to be false
      end
    end

    describe "#complete!" do
      it "completes a confirmed booking" do
        booking.update_columns(status: "confirmed", date: Date.current)
        expect(booking.complete!).to be true
        expect(booking.reload.status).to eq("completed")
        expect(booking.completed_at).to be_present
      end

      it "returns false for non-confirmed bookings" do
        booking.date = Date.current
        expect(booking.complete!).to be false
      end
    end
  end

  describe "#duration_minutes" do
    it "calculates duration in minutes" do
      service = create(:service, duration: 90)
      booking = create(:booking, service: service)
      expect(booking.duration_minutes).to eq(90)
    end
  end
end
