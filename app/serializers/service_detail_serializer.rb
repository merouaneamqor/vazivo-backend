# frozen_string_literal: true

class ServiceDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :duration, :price,
             :formatted_duration, :formatted_price,
             :created_at, :updated_at

  attribute :image_url, if: :image_attached?

  belongs_to :business, serializer: BusinessSerializer

  def name
    object.translated_name
  end

  def description
    object.translated_description
  end

  def image_url
    return nil unless object.image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(object.image, only_path: true)
  end

  def image_attached?
    object.image.attached?
  end
end
