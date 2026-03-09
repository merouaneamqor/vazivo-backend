# frozen_string_literal: true

class ServiceSerializer < ActiveModel::Serializer
  include StorageUrlConcern

  attributes :id, :name, :description, :duration, :price,
             :formatted_duration, :formatted_price,
             :category_id, :category_name, :parent_category_name, :parent_category_slug,
             :service_category_id, :service_category,
             :business_id, :business_name, :business_slug, :image_url, :created_at

  def service_category
    return nil unless object.service_category

    {
      id: object.service_category.id,
      name: object.service_category.name,
      color: object.service_category.color,
    }
  end

  def category_name
    object.category&.translated_name || object.translated_name
  end

  def parent_category_name
    object.parent_category&.translated_name
  end

  delegate :parent_category_slug, to: :object

  def name
    object.translated_name
  end

  def description
    object.translated_description.presence || object.read_attribute(:description).presence ||
      object.read_attribute(:description_en).presence || object.read_attribute(:description_fr).presence ||
      object.read_attribute(:description_ar).presence
  end

  def business_name
    object.business.translated_name
  end

  def business_slug
    object.business.translated_slug
  end

  def image_url
    return object.image_url if object.image_url.present?
    return storage_url(object.image) if object.image.present?

    nil
  end
end
