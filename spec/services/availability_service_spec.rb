# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvailabilityService do
  let(:business) do
    create(:business, opening_hours: {
      "monday" => { "open" => "09:00", "close" => "17:00" },
      "tuesday" => { "open" => "09:00", "close" => "17:00" },
      "sunday" => { "open" => nil, "close" => nil },
    })
  end
  let(:service) { create(:service, business: business, duration: 60) }
  let(:availability_service) { described_class.new(service) }

  describe "#available_slots" do
    context "on a business day" do
      let(:monday) { Date.current.next_occurring(:monday) }

      it "returns available time slots" do
        slots = availability_service.available_slots(monday)

        expect(slots).to be_an(Array)
        expect(slots.first[:time]).to eq("09:00")
        expect(slots.all? { |s| s[:available] }).to be true
      end

      it "marks booked slots as unavailable" do
        create(:booking, service: service, date: monday, start_time: "10:00")

        slots = availability_service.available_slots(monday)
        booked_slot = slots.find { |s| s[:time] == "10:00" }

        expect(booked_slot[:available]).to be false
      end

      it "does not block slots for cancelled bookings (slot visible on agenda again)" do
        create(:booking, :cancelled, service: service, date: monday, start_time: "10:00")

        slots = availability_service.available_slots(monday)
        slot_10 = slots.find { |s| s[:time] == "10:00" }

        expect(slot_10).to be_present
        expect(slot_10[:available]).to be true
      end

      it "frees the slot when a booking is cancelled" do
        booking = create(:booking, :confirmed, service: service, date: monday, start_time: "10:00")

        expect(availability_service.available?(monday, "10:00")).to be false

        booking.cancel!

        expect(availability_service.available?(monday, "10:00")).to be true
      end

      it "respects service duration" do
        slots = availability_service.available_slots(monday)
        last_slot = slots.last

        # With 60min duration and 17:00 close, last slot should be 16:00
        expect(last_slot[:time]).to eq("16:00")
      end
    end

    context "on a closed day" do
      let(:sunday) { Date.current.next_occurring(:sunday) }

      it "returns empty array" do
        slots = availability_service.available_slots(sunday)

        expect(slots).to be_empty
      end
    end

    context "for past dates" do
      it "returns empty array" do
        slots = availability_service.available_slots(Date.yesterday)

        expect(slots).to be_empty
      end
    end
  end

  describe "#available?" do
    let(:monday) { Date.current.next_occurring(:monday) }

    it "returns true for available slot" do
      expect(availability_service.available?(monday, "10:00")).to be true
    end

    it "returns false for booked slot" do
      create(:booking, service: service, date: monday, start_time: "10:00")

      expect(availability_service.available?(monday, "10:00")).to be false
    end

    it "returns false for time outside business hours" do
      expect(availability_service.available?(monday, "07:00")).to be false
    end
  end

  describe "#availability_calendar" do
    let(:start_date) { Date.current.next_occurring(:monday) }
    let(:end_date) { start_date + 6.days }

    it "returns calendar for date range" do
      calendar = availability_service.availability_calendar(start_date, end_date)

      expect(calendar.length).to eq(7)
      expect(calendar.first[:date]).to eq(start_date.to_s)
    end

    it "includes is_open status for each day" do
      calendar = availability_service.availability_calendar(start_date, end_date)
      sunday = calendar.find { |d| d[:day_name] == "Sunday" }

      expect(sunday[:is_open]).to be false
    end
  end
end
