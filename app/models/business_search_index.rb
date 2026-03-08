class BusinessSearchIndex < ApplicationRecord
  belongs_to :business
  belongs_to :city, optional: true
  belongs_to :category, optional: true
end

