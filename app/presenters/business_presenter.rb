# frozen_string_literal: true

class BusinessPresenter
  attr_reader :business

  delegate :id, :address, :phone, :email, :website,
           :opening_hours, :created_at, to: :business

  # City as display string (legacy column or association name) so API never returns raw City object
  def city
    business.read_attribute(:city).presence || business.city&.name
  end

  def name
    business.translated_name
  end

  def description
    business.translated_description
  end

  def slug
    business.translated_slug
  end

  # Category as display string (denormalized column or first from categories jsonb)
  def category
    raw = business.read_attribute(:category).presence
    raw = Array(business.read_attribute(:categories)).first if raw.blank?
    Category.translated_name_for(raw)
  end

  def initialize(business)
    @business = business
  end

  def as_json(*)
    {
      id: id,
      slug: slug,
      name: name,
      description: description,
      category: category,
      cuisine_types: cuisine_types,
      price_range: price_range,
      table_capacity: table_capacity,
      address: address,
      city: city,
      lat: lat,
      lng: lng,
      phone: phone,
      email: email,
      website: website,
      opening_hours: opening_hours,
      average_rating: average_rating,
      total_reviews: total_reviews,
      min_price: min_price,
      max_price: max_price,
      is_open: is_open?,
      logo_url: logo_url,
      image_urls: image_urls,
      created_at: created_at,
      premium: business.premium?,
    }
  end

  def cuisine_types
    business.respond_to?(:cuisine_types) && business.cuisine_types.present? ? business.cuisine_types : []
  end

  def price_range
    business.respond_to?(:price_range) ? business.price_range : nil
  end

  def table_capacity
    business.respond_to?(:table_capacity) ? business.table_capacity : nil
  end

  def lat
    business.lat&.to_f
  end

  def lng
    business.lng&.to_f
  end

  def average_rating
    business.average_rating.to_f
  end

  delegate :total_reviews, to: :business

  def min_price
    business.min_service_price&.to_f
  end

  def max_price
    business.max_service_price&.to_f
  end

  delegate :is_open?, to: :business
  delegate :logo_url, :image_urls, to: :business
end
