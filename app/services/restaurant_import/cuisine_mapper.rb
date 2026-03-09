# frozen_string_literal: true

module RestaurantImport
  # Maps TripAdvisor (or other) cuisine strings to Category canonical names.
  # Used by ProdDataSeedFileLoadService when importing prod_data/seed_file.json.
  class CuisineMapper
    CANONICAL = Category::CANONICAL_NAMES.freeze

    # Keywords (case-insensitive) → canonical name
    MAPPING = {
      "moroccan" => "Moroccan",
      "maroc" => "Moroccan",
      "marocaine" => "Moroccan",
      "mediterranean" => "Mediterranean",
      "mediterranee" => "Mediterranean",
      "mediterranéen" => "Mediterranean",
      "italian" => "Italian",
      "italienne" => "Italian",
      "pizza" => "Italian",
      "pasta" => "Italian",
      "french" => "French",
      "française" => "French",
      "francais" => "French",
      "bistro" => "French",
      "japanese" => "Japanese",
      "japonaise" => "Japanese",
      "sushi" => "Japanese",
      "seafood" => "Seafood",
      "fruits de mer" => "Seafood",
      "fish" => "Seafood",
      "international" => "International",
      "fusion" => "International",
      "european" => "International",
      "européen" => "International",
      "american" => "International",
      "street food" => "Street food",
      "streetfood" => "Street food",
      "fast food" => "Street food",
      "fastfood" => "Street food",
      "burger" => "Street food",
      "snack" => "Street food",
    }.freeze

    DEFAULT = "International"

    class << self
      # @param cuisines [Array<String>, nil] e.g. ["Moroccan", "Mediterranean"]
      # @return [String] canonical category name
      def to_canonical(cuisines)
        return DEFAULT if cuisines.blank?

        Array(cuisines).each do |raw|
          next if raw.blank?

          key = raw.to_s.strip.downcase
          return MAPPING[key] if MAPPING.key?(key)

          # Try partial match (e.g. "Moroccan cuisine" contains "moroccan")
          found = MAPPING.find { |k, _| key.include?(k) }
          return found.second if found
        end

        # Fallback: check if any canonical name appears in the cuisine string
        CANONICAL.each do |canon|
          return canon if Array(cuisines).any? { |c| c.to_s.strip.downcase.include?(canon.downcase) }
        end

        DEFAULT
      end
    end
  end
end
