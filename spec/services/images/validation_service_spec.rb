# frozen_string_literal: true

require "rails_helper"

RSpec.describe Images::ValidationService do
  let(:valid_file) do
    double("file",
           tempfile: double("tempfile"),
           size: 2.megabytes,
           content_type: "image/jpeg")
  end

  describe "#valid?" do
    context "with valid file" do
      it "returns true" do
        service = described_class.new(valid_file)
        expect(service.valid?).to be true
      end
    end

    context "with nil file" do
      it "returns false" do
        service = described_class.new(nil)
        expect(service.valid?).to be false
        expect(service.errors).to include("File is required")
      end
    end

    context "with oversized file" do
      it "returns false" do
        large_file = double("file",
                            tempfile: double("tempfile"),
                            size: 6.megabytes,
                            content_type: "image/jpeg")
        service = described_class.new(large_file)
        expect(service.valid?).to be false
        expect(service.errors).to include(match(/exceeds.*5MB/))
      end
    end

    context "with invalid MIME type" do
      it "returns false" do
        invalid_file = double("file",
                              tempfile: double("tempfile"),
                              size: 2.megabytes,
                              content_type: "application/pdf")
        service = described_class.new(invalid_file)
        expect(service.valid?).to be false
        expect(service.errors).to include(match(/Invalid MIME type/))
      end
    end

    context "with invalid file object" do
      it "returns false" do
        invalid_file = double("file", size: 2.megabytes, content_type: "image/jpeg")
        service = described_class.new(invalid_file)
        expect(service.valid?).to be false
        expect(service.errors).to include("Invalid file format")
      end
    end
  end

  describe "#errors" do
    it "returns array of error messages" do
      service = described_class.new(nil)
      expect(service.errors).to be_an(Array)
      expect(service.errors).not_to be_empty
    end
  end
end
