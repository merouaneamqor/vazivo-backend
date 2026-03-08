# frozen_string_literal: true

class ReviewSerializer < ActiveModel::Serializer
  attributes :id, :rating, :comment, :created_at,
             :user_name, :user_id, :booking_id, :business_id

  def user_name
    object.user&.name || "Anonymous"
  end
end
