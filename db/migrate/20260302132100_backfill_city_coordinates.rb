# frozen_string_literal: true

class BackfillCityCoordinates < ActiveRecord::Migration[7.1]
  # Known Moroccan city coordinates (match by slug or normalized name)
  COORDS = {
    "casablanca" => [33.5731, -7.5898],
    "rabat" => [34.0209, -6.8416],
    "marrakech" => [31.6295, -7.9811],
    "fes" => [34.0331, -5.0003],
    "tanger" => [35.7595, -5.834],
    "tangier" => [35.7595, -5.834],
    "agadir" => [30.4278, -9.5981],
    "meknes" => [33.895, -5.5547],
    "oujda" => [34.6867, -1.9114],
    "kenitra" => [34.2611, -6.5802],
    "tetouan" => [35.5769, -5.3684],
    "sale" => [34.0389, -6.8166],
    "temara" => [33.9283, -6.9066],
    "mohammedia" => [33.6861, -7.3829],
    "essaouira" => [31.5085, -9.7595],
    "nador" => [35.1682, -2.9333],
    "el-jadida" => [33.2542, -8.5062],
    "eljadida" => [33.2542, -8.5062],
    "khouribga" => [32.8847, -6.9066],
    "beni-mellal" => [32.3373, -6.3498],
    "benimellal" => [32.3373, -6.3498],
  }.freeze

  def up
    return unless column_exists?(:cities, :lat) && column_exists?(:cities, :lng)

    City.reset_column_information if defined?(City)
    return unless defined?(City)

    City.find_each do |city|
      key = city.slug.presence&.downcase&.tr("_", "-")
      key ||= city.name.presence&.parameterize
      next unless key

      lat, lng = COORDS[key] || COORDS[key.gsub(/\s+/, "-")]
      next unless lat && lng

      city.update_columns(lat: lat, lng: lng)
    end
  end

  def down
    if column_exists?(:cities, :lat)
      City.update_all(lat: nil, lng: nil) if defined?(City)
    end
  end
end
