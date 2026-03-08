# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingPayment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:booking) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }

    it {
      expect(subject).to validate_inclusion_of(:status).in_array(["pending", "processing", "succeeded", "failed",
                                                                  "refunded"])
    }
  end

  describe "scopes" do
    let(:user) { create(:user, :customer) }
    let(:booking1) { create(:booking, user: user) }
    let(:booking2) { create(:booking, user: user) }
    let(:booking3) { create(:booking, user: user) }

    let!(:successful_payment) { create(:booking_payment, booking: booking1, user: user, status: "succeeded") }
    let!(:pending_payment) { create(:booking_payment, booking: booking2, user: user, status: "pending") }
    let!(:failed_payment) { create(:booking_payment, booking: booking3, user: user, status: "failed") }

    describe ".successful" do
      it "returns only succeeded payments" do
        expect(described_class.successful).to include(successful_payment)
        expect(described_class.successful).not_to include(pending_payment, failed_payment)
      end
    end

    describe ".pending" do
      it "returns only pending payments" do
        expect(described_class.pending).to include(pending_payment)
        expect(described_class.pending).not_to include(successful_payment, failed_payment)
      end
    end
  end

  describe "status methods" do
    let(:user) { create(:user, :customer) }
    let(:booking) { create(:booking, user: user) }
    let(:payment) { create(:booking_payment, booking: booking, user: user, status: "pending") }

    describe "#mark_as_paid!" do
      it "updates status to succeeded and sets paid_at" do
        expect { payment.mark_as_paid! }.to change(payment, :status).from("pending").to("succeeded")
        expect(payment.paid_at).to be_present
      end
    end

    describe "#mark_as_failed!" do
      it "updates status to failed" do
        expect { payment.mark_as_failed! }.to change(payment, :status).from("pending").to("failed")
      end
    end

    describe "#refund!" do
      it "updates status to refunded and sets refunded_at" do
        payment.mark_as_paid!
        expect { payment.refund! }.to change(payment, :status).from("succeeded").to("refunded")
        expect(payment.refunded_at).to be_present
      end
    end
  end
end
