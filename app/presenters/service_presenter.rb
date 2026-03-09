# frozen_string_literal: true

class ServicePresenter
  include Rails.application.routes.url_helpers

  attr_reader :service

  delegate :id, :duration, :created_at, :updated_at, to: :service

  def name
    service.translated_name
  end

  def description
    service.translated_description
  end

  def initialize(service)
    @service = service
  end

  def as_json(*)
    {
      id: id,
      name: name,
      description: description,
      duration: duration,
      price: price,
      formatted_duration: formatted_duration,
      formatted_price: formatted_price,
      category_id: service.category_id,
      category_name: service.category_name,
      parent_category_name: service.parent_category_name,
      parent_category_slug: service.parent_category_slug,
      service_category_id: service.service_category_id,
      service_category: service_category_json,
      business_id: business_id,
      business_name: business_name,
      business_slug: business_slug,
      image_url: image_url,
      created_at: created_at,
      updated_at: updated_at,
    }
  end

  def price
    service.price.to_f
  end

  delegate :formatted_duration, to: :service

  delegate :formatted_price, to: :service

  delegate :business_id, to: :service

  def business_name
    service.business_translated_name
  end

  def business_slug
    service.business_translated_slug
  end

  def image_url
    return nil unless service.image?

    service.image.url
  end

  def service_category_json
    return nil unless service.service_category

    {
      id: service.service_category_id,
      name: service.category_name,
      color: service.category_color,
    }
  end
end
