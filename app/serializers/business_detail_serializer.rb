# frozen_string_literal: true

class BusinessDetailSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :description, :category, :categories, :address, :city, :country, :neighborhood,
             :lat, :lng, :phone, :email, :website,
             :opening_hours, :average_rating, :total_reviews,
             :is_open, :today_hours,
             :cuisine_types, :price_range, :table_capacity,
             :logo_url, :image_urls,
             :created_at, :updated_at

  belongs_to :user, serializer: UserSerializer
  has_many :services, serializer: ServiceSerializer
  has_many :reviews, serializer: ReviewSerializer

  def is_open
    object.is_open?
  end

  def cuisine_types
    object.respond_to?(:cuisine_types) && object.cuisine_types.present? ? object.cuisine_types : []
  end

  def price_range
    object.respond_to?(:price_range) ? object.price_range : nil
  end

  def table_capacity
    object.respond_to?(:table_capacity) ? object.table_capacity : nil
  end

  def logo_url
    object.logo_url
  end

  def image_urls
    object.image_urls || []
  end

  def name
    object.translated_name
  end

  def description
    object.translated_description
  end

  def slug
    object.translated_slug
  end

  def services
    object.services.kept
  end

  def reviews
    object.reviews.recent.limit(10)
  end

  def category
    Category.translated_name_for(object.read_attribute(:category))
  end

  def categories
    (object.categories || []).map { |c| c.respond_to?(:name) ? Category.translated_name_for(c.name) : Category.translated_name_for(c) }
  end

  # Return city/neighborhood name string: legacy column first, then association (for API/SEO paths).
  def city
    object.read_attribute(:city).presence || (object.city.respond_to?(:name) ? object.city.name : nil)
  end

  def neighborhood
    object.read_attribute(:neighborhood).presence || (object.neighborhood.respond_to?(:name) ? object.neighborhood.name : nil)
  end
end
