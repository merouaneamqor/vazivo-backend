# frozen_string_literal: true

module Images
  class ValidationService
    MAX_FILE_SIZE = 5.megabytes
    ALLOWED_MIME_TYPES = ["image/png", "image/jpeg", "image/jpg"].freeze

    def initialize(file)
      @file = file
    end

    def valid?
      errors.empty?
    end

    def errors
      @errors ||= validate
    end

    private

    def validate
      errors = []
      errors << "File is required" if @file.blank?
      return errors if @file.blank?

      errors << "Invalid file format" unless valid_file_object?
      errors << "File size exceeds #{MAX_FILE_SIZE / 1.megabyte}MB limit" if exceeds_size_limit?
      errors << "Invalid MIME type. Allowed: #{ALLOWED_MIME_TYPES.join(', ')}" unless valid_mime_type?
      errors
    end

    def valid_file_object?
      @file.respond_to?(:tempfile) || @file.respond_to?(:path)
    end

    def exceeds_size_limit?
      @file.size > MAX_FILE_SIZE
    end

    def valid_mime_type?
      ALLOWED_MIME_TYPES.include?(@file.content_type)
    end
  end
end
