# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingService do
  let(:customer) { create(:user, :customer) }
  let(:provider) { create(:user, :provider) }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business, duration: 60) }

  describe "#create" do
    let(:booking_service) { described_class.new(customer) }
    let(:valid_params) do
      {
        service_id: service.id,
        date: Date.tomorrow.strftime("%Y-%m-%d"),
        start_time: "10:00",
        notes: "Test booking",
      }
    end

    context "with valid params" do
      it "creates a booking" do
        expect do
          booking_service.create(valid_params)
        end.to change(Booking, :count).by(1)
      end

      it "returns success with booking" do
        result = booking_service.create(valid_params)

        expect(result[:success]).to be true
        expect(result[:booking]).to be_a(Booking)
        expect(result[:booking].user).to eq(customer)
        expect(result[:booking].service).to eq(service)
      end

      it "sets the business from service" do
        result = booking_service.create(valid_params)

        expect(result[:booking].business).to eq(business)
      end
    end

    context "with non-existent service" do
      it "returns failure" do
        result = booking_service.create(valid_params.merge(service_id: 999_999))

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Service not found")
      end
    end

    context "with discarded service" do
      before { service.discard }

      it "returns failure" do
        result = booking_service.create(valid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Service not found")
      end
    end

    context "with discarded business" do
      before { business.discard }

      it "returns failure" do
        result = booking_service.create(valid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Business is not available")
      end
    end

    context "with unavailable time slot" do
      before do
        create(:booking, service: service, user: create(:user, :customer),
                         date: Date.tomorrow, start_time: "10:00")
      end

      it "returns failure" do
        result = booking_service.create(valid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("This time slot is not available")
      end
    end
  end

  describe "#cancel" do
    let(:booking) { create(:booking, user: customer, service: service, business: business) }
    let(:booking_service) { described_class.new(customer) }

    context "as the booking owner" do
      it "cancels the booking" do
        result = booking_service.cancel(booking)

        expect(result[:success]).to be true
        expect(booking.reload.status).to eq("cancelled")
      end
    end

    context "as the business owner" do
      let(:provider_service) { described_class.new(provider) }

      it "cancels the booking" do
        result = provider_service.cancel(booking)

        expect(result[:success]).to be true
        expect(booking.reload.status).to eq("cancelled")
      end
    end

    context "as another user" do
      let(:other_user) { create(:user, :customer) }
      let(:other_service) { described_class.new(other_user) }

      it "returns failure" do
        result = other_service.cancel(booking)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("You are not authorized to cancel this booking")
      end
    end

    context "when booking cannot be cancelled" do
      before { booking.update_column(:status, "completed") }

      it "returns failure" do
        result = booking_service.cancel(booking)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("This booking cannot be cancelled")
      end
    end
  end

  describe "#confirm" do
    let(:booking) { create(:booking, user: customer, service: service, business: business) }
    let(:provider_service) { described_class.new(provider) }

    context "as the business owner" do
      it "confirms the booking" do
        result = provider_service.confirm(booking)

        expect(result[:success]).to be true
        expect(booking.reload.status).to eq("confirmed")
        expect(booking.confirmed_at).to be_present
      end
    end

    context "as the booking owner (customer)" do
      let(:customer_service) { described_class.new(customer) }

      it "returns failure" do
        result = customer_service.confirm(booking)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("You are not authorized to confirm this booking")
      end
    end

    context "when booking cannot be confirmed" do
      before { booking.update_column(:status, "confirmed") }

      it "returns failure" do
        result = provider_service.confirm(booking)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("This booking cannot be confirmed")
      end
    end
  end

  describe "#complete" do
    let(:booking) do
      create(:booking, :confirmed, user: customer, service: service, business: business, date: Date.current)
    end
    let(:provider_service) { described_class.new(provider) }

    context "as the business owner" do
      it "completes the booking" do
        result = provider_service.complete(booking)

        expect(result[:success]).to be true
        expect(booking.reload.status).to eq("completed")
        expect(booking.completed_at).to be_present
      end
    end

    context "when booking is in the future" do
      before { booking.update_column(:date, Date.tomorrow) }

      it "returns failure" do
        result = provider_service.complete(booking)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("This booking cannot be completed")
      end
    end
  end

  describe "#reschedule" do
    let(:booking) { create(:booking, user: customer, service: service, business: business) }
    let(:booking_service) { described_class.new(customer) }
    let(:new_date) { (Date.tomorrow + 1.day).strftime("%Y-%m-%d") }
    let(:new_time) { "14:00" }

    context "with valid new slot" do
      it "reschedules the booking" do
        result = booking_service.reschedule(booking, new_date, new_time)

        expect(result[:success]).to be true
        expect(booking.reload.date.strftime("%Y-%m-%d")).to eq(new_date)
        expect(booking.start_time.strftime("%H:%M")).to eq(new_time)
      end
    end

    context "when new slot is unavailable" do
      before do
        create(:booking, service: service, user: create(:user, :customer),
                         date: Date.parse(new_date), start_time: new_time)
      end

      it "returns failure" do
        result = booking_service.reschedule(booking, new_date, new_time)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("The new time slot is not available")
      end
    end

    context "when booking cannot be rescheduled" do
      before { booking.update_column(:status, "completed") }

      it "returns failure" do
        result = booking_service.reschedule(booking, new_date, new_time)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("This booking cannot be rescheduled")
      end
    end
  end
end
