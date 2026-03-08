# frozen_string_literal: true

module StorageUrlConcern
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  # Generate URL for an attached file
  def storage_url(attachment)
    return nil unless attachment&.attached?

    blob = attachment.is_a?(ActiveStorage::Attached::One) ? attachment.blob : attachment

    case Rails.application.config.active_storage.service
    when :minio
      minio_url(blob)
    when :cloudinary
      cloudinary_url(blob)
    else
      rails_blob_url(blob, only_path: true)
    end
  end

  # Generate URLs for multiple attachments
  def storage_urls(attachments)
    return [] unless attachments&.attached?

    attachments.map { |blob| single_storage_url(blob) }.compact
  end

  private

  def single_storage_url(blob)
    case Rails.application.config.active_storage.service
    when :minio
      minio_url(blob)
    when :cloudinary
      cloudinary_url(blob)
    else
      rails_blob_url(blob, only_path: true)
    end
  end

  def minio_url(blob)
    endpoint = ENV.fetch("MINIO_PUBLIC_ENDPOINT", "http://localhost:9000")
    bucket = ENV.fetch("MINIO_BUCKET", "ollazen-development")
    key = blob.key

    "#{endpoint}/#{bucket}/#{key}"
  end

  def cloudinary_url(blob)
    return nil unless defined?(Cloudinary)

    folder = ENV.fetch("CLOUDINARY_FOLDER", "glow").presence
    public_id = folder ? "#{folder}/#{blob.key}" : blob.key
    CloudinaryDeliveryUrlHelper.url(public_id)
  end
end
