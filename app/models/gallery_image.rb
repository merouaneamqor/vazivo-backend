# frozen_string_literal: true

class GalleryImage
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :image, :string
  attribute :public_id, :string

  validates :image, presence: true
  validates :public_id, presence: true
end
