# frozen_string_literal: true

json.businesses @businesses do |business|
  json.extract! business, :id, :name, :description, :category, :address, :city, :lat, :lng, :phone, :email, :website,
                :opening_hours, :created_at
  json.average_rating business.average_rating
  json.total_reviews business.total_reviews
  json.min_price business.min_service_price
  json.max_price business.max_service_price

  json.user do
    json.extract! business.user, :id, :name, :email, :phone, :role, :created_at
  end

  json.logo_url attachment_url(business.logo) if business.logo.attached?

  if business.images.attached?
    json.image_urls attachment_urls(business.images)
  else
    json.image_urls []
  end
end

json.meta do
  json.current_page @businesses.current_page
  json.total_pages @businesses.total_pages
  json.total_count @businesses.total_count
  json.per_page @businesses.limit_value
end
