# frozen_string_literal: true

class BusinessCategory < ApplicationRecord
  belongs_to :business
  belongs_to :category

  validates :business_id, uniqueness: { scope: :category_id }
end
