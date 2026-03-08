# frozen_string_literal: true

module StorageUrlHelper
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  # Generate URL for an attached file
  # In development with MinIO: returns full MinIO URL
  # In production with Cloudinary: returns Cloudinary URL
  # Fallback: returns Rails blob URL
  def attachment_url(attachment)
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
  def attachment_urls(attachments)
    return [] unless attachments&.attached?

    attachments.map { |blob| single_attachment_url(blob) }.compact
  end

  private

  def single_attachment_url(blob)
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
    # Build MinIO public URL
    endpoint = ENV.fetch("MINIO_PUBLIC_ENDPOINT", "http://localhost:9000")
    bucket = ENV.fetch("MINIO_BUCKET", "glow-development")
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
