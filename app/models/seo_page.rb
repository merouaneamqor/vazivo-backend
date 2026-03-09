# frozen_string_literal: true

class SeoPage < ApplicationRecord
  belongs_to :business, optional: true

  validates :path, presence: true, uniqueness: true

  # Normalize path: strip leading/trailing slashes and whitespace
  before_validation :normalize_path

  scope :for_path, ->(p) { where(path: p.to_s.sub(%r{\A/+}, "").sub(%r{/+\z}, "")) }

  private

  def normalize_path
    self.path = path.to_s.strip.sub(%r{\A/+}, "").sub(%r{/+\z}, "")
  end
end
