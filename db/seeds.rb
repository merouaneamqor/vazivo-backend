# frozen_string_literal: true

# Comprehensive seed file for Vazivo restaurant platform with Moroccan data
Rails.logger.debug "🌱 Seeding database with Moroccan data..."
Rails.logger.debug "=" * 60

# Safe category label for a business (column or first from categories jsonb)
def seed_business_category(business)
  return nil unless business

  if business.class.column_names.include?("category")
    val = business.read_attribute(:category)
    return val.presence
  end
  return nil unless business.class.column_names.include?("categories")

  raw = business.read_attribute(:categories)
  return raw.first.presence if raw.is_a?(Array) && raw.any?

  nil
end

begin
  require "faker"
  Faker::Config.locale = "fr"
rescue LoadError
  Faker = nil
end

# Clear existing data (optional - comment out if you want to keep existing data)
# User.destroy_all
# Business.destroy_all
# Service.destroy_all
# Booking.destroy_all
# Review.destroy_all
# BookingPayment.destroy_all

# ============================================================================
# MOROCCAN CITIES DATA
# ============================================================================
MOROCCAN_CITIES = [
  { name: "Casablanca", lat: 33.5731, lng: -7.5898 },
  { name: "Rabat", lat: 34.0209, lng: -6.8416 },
  { name: "Marrakech", lat: 31.6295, lng: -7.9811 },
  { name: "Fes", lat: 34.0331, lng: -5.0003 },
  { name: "Tangier", lat: 35.7595, lng: -5.8340 },
  { name: "Agadir", lat: 30.4278, lng: -9.5981 },
  { name: "Meknes", lat: 33.8950, lng: -5.5547 },
  { name: "Oujda", lat: 34.6867, lng: -1.9114 },
  { name: "Kenitra", lat: 34.2611, lng: -6.5802 },
  { name: "Tetouan", lat: 35.5769, lng: -5.3684 },
].freeze

# ============================================================================
# CREATE USERS
# ============================================================================
Rails.logger.debug "\n👥 Creating users..."

# Admin user (always ensure consistent credentials and admin role)
admin = User.find_or_initialize_by(email: "admin@vazivo.com")
admin.name = "Merouane Admin"
admin.password = "password123"
admin.role = "admin"
admin.admin_role ||= "superadmin"
admin.phone ||= "+212701086726"
admin.save!
Rails.logger.debug { "  ✓ Admin: #{admin.email} (role=#{admin.role}, admin_role=#{admin.admin_role || 'nil'})" }

# Provider users (business owners)
providers_data = [
  { name: "Fatima Zahra", email: "fatima@vazivo.com", phone: "+212612345679", city: "Casablanca" },
  { name: "Mohamed Amine", email: "mohamed@vazivo.com", phone: "+212612345680", city: "Rabat" },
  { name: "Aicha Benali", email: "aicha@vazivo.com", phone: "+212612345681", city: "Marrakech" },
  { name: "Youssef Alami", email: "youssef@vazivo.com", phone: "+212612345682", city: "Fes" },
  { name: "Sanae Idrissi", email: "sanae@vazivo.com", phone: "+212612345683", city: "Tangier" },
  { name: "Hassan Tazi", email: "hassan@vazivo.com", phone: "+212612345684", city: "Agadir" },
  { name: "Laila Bensaid", email: "laila@vazivo.com", phone: "+212612345685", city: "Casablanca" },
  { name: "Omar Cherkaoui", email: "omar@vazivo.com", phone: "+212612345686", city: "Rabat" },
]

providers = providers_data.map do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.name = data[:name]
    u.password = "password123"
    u.role = "provider"
    u.provider_status = "confirmed"
    u.phone = data[:phone]
  end
  user.update!(provider_status: "confirmed") if user.role == "provider"
  Rails.logger.debug { "  ✓ Provider: #{user.email}" }
  user
end

# Customer users
customers_data = [
  { name: "Sara Alami", email: "sara@vazivo.com", phone: "+212612345700" },
  { name: "Mehdi Benjelloun", email: "mehdi@vazivo.com", phone: "+212612345701" },
  { name: "Nadia El Fassi", email: "nadia@vazivo.com", phone: "+212612345702" },
  { name: "Karim Bennis", email: "karim@vazivo.com", phone: "+212612345703" },
  { name: "Imane Tazi", email: "imane@vazivo.com", phone: "+212612345704" },
  { name: "Yassine Alaoui", email: "yassine@vazivo.com", phone: "+212612345705" },
  { name: "Hind Idrissi", email: "hind@vazivo.com", phone: "+212612345706" },
  { name: "Amine Cherkaoui", email: "amine@vazivo.com", phone: "+212612345707" },
  { name: "Salma Bensaid", email: "salma@vazivo.com", phone: "+212612345708" },
  { name: "Omar Alami", email: "omar.customer@vazivo.com", phone: "+212612345709" },
]

customers = customers_data.map do |data|
  User.find_or_create_by!(email: data[:email]) do |user|
    user.name = data[:name]
    user.password = "password123"
    user.role = "customer"
    user.phone = data[:phone]
  end.tap { |u| Rails.logger.debug "  ✓ Customer: #{u.email}" }
end

# ============================================================================
# CATEGORIES: Cuisines (top-level). Each has one "Table reservation" experience.
# ============================================================================
SEED_ACTS = [
  { name: "Moroccan", slug: "moroccan",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "Mediterranean", slug: "mediterranean",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "Italian", slug: "italian",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "French", slug: "french",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "Japanese", slug: "japanese",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "Seafood", slug: "seafood",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "International", slug: "international",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table for dining", duration: 120, price: 0.0 }] },
  { name: "Street food", slug: "street-food",
    subacts: [{ name: "Table reservation", slug: "table-reservation", description: "Reserve a table", duration: 60, price: 0.0 }] },
].freeze

CANONICAL_CATEGORIES = SEED_ACTS.map { |a| a[:name] }.freeze
SEED_ACTS_SUBACTS = SEED_ACTS.to_h { |a| [a[:name], a[:subacts]] }.freeze

Rails.logger.debug "\n📂 Creating categories (acts + subacts)..."
if defined?(Category) && Category.table_exists?
  # Remove any existing acts whose slug is not in our seed list
  Category.acts.where.not(slug: SEED_ACTS.map { |a| a[:slug] }).destroy_all

  SEED_ACTS.each_with_index do |act_data, act_position|
    slug_val = act_data[:slug]
    name_val = act_data[:name]
    act = Category.find_or_initialize_by(slug: slug_val)
    act.assign_attributes(
      name_en: name_val,
      name_fr: name_val,
      name_ar: name_val,
      slug_en: slug_val,
      slug_fr: slug_val,
      slug_ar: slug_val,
      parent_id: nil,
      position: act_position
    )
    act[:name] = name_val
    act[:slug] = slug_val
    act.save!

    act_data[:subacts].each_with_index do |sub_data, sub_position|
      sub_slug = sub_data[:slug]
      sub_name = sub_data[:name]
      subact = Category.find_or_initialize_by(parent_id: act.id, slug: sub_slug)
      subact.assign_attributes(
        name_en: sub_name,
        name_fr: sub_name,
        name_ar: sub_name,
        slug_en: sub_slug,
        slug_fr: sub_slug,
        slug_ar: sub_slug,
        position: sub_position
      )
      subact[:name] = sub_name
      subact[:slug] = sub_slug
      subact.save!
    end
  end

  total_subacts = Category.subacts.count
  Rails.logger.debug { "  ✓ Acts: #{CANONICAL_CATEGORIES.join(', ')}" }
  Rails.logger.debug { "  ✓ Subacts: #{total_subacts} prestations" }
end

def find_subact(act_name, subact_name)
  return nil unless defined?(Category) && Category.table_exists?

  act = Category.acts.find_by(name: act_name)
  return nil unless act

  Category.subacts.find_by(parent_id: act.id, name: subact_name)
end

# Return a ServiceCategory for the business (Service requires service_category_id). Use default name so all seeded services have one.
def seed_service_category_for(business, name = "Prestations")
  return nil unless business && defined?(ServiceCategory) && ServiceCategory.table_exists?

  @seed_service_categories_cache ||= {}
  key = "#{business.id}-#{name}"
  return @seed_service_categories_cache[key] if @seed_service_categories_cache.key?(key)

  cat = business.service_categories.find_or_create_by!(name: name) do |sc|
    sc.position = (business.service_categories.maximum(:position) || -1) + 1
  end
  @seed_service_categories_cache[key] = cat
  cat
end

# ============================================================================
# CREATE BUSINESSES
# ============================================================================
Rails.logger.debug "\n🏢 Creating businesses..."

# Ensure City records exist for all city names we use (Business belongs_to :city expects a City record).
# Returns city_id (or nil) and never loads a City record so validations cannot be triggered.
def seed_city_for(name)
  return nil if name.blank?

  @seed_city_ids_cache ||= {}
  return @seed_city_ids_cache[name] if @seed_city_ids_cache.key?(name)
  return nil unless defined?(City) && City.table_exists?

  id = City.where("LOWER(name) = ?", name.to_s.strip.downcase).pick(:id) ||
       City.where("LOWER(slug) = ?", name.to_s.strip.parameterize.downcase).pick(:id)

  unless id
    name_str = name.to_s.strip
    base = name_str.parameterize.presence || "city"
    slug = base
    n = 1
    while City.exists?(slug: slug)
      slug = "#{base}-#{n}"
      n += 1
    end

    begin
      now = Time.current
      result = City.insert_all(
        [{ name: name_str, slug: slug, position: 0, created_at: now, updated_at: now }],
        returning: [:id]
      )
      id = result.rows.dig(0, 0) if result.respond_to?(:rows) && result.rows.present?
      id ||= City.where(slug: slug).pick(:id)
    rescue StandardError => e
      Rails.logger.warn "seed_city_for(#{name.inspect}) insert_all failed: #{e.message}"
      return nil
    end
    raise "Failed to create City #{name_str}" unless id
  end
  @seed_city_ids_cache[name] = id
  id
end

businesses_data = [
  {
    name: "La Sqala",
    description: "Restaurant marocain dans un cadre historique. Cuisine traditionnelle et raffinée.",
    category: "Moroccan",
    city: "Casablanca",
    address: "Boulevard des Almohades, Casablanca",
    lat: 33.5750,
    lng: -7.5950,
    phone: "+212522456789",
    email: "contact@lasqala.ma",
    provider_index: 0,
    cuisine_types: ["Moroccan", "Mediterranean"],
    price_range: "$$",
    table_capacity: 30,
  },
  {
    name: "Le Comptoir Darna",
    description: "Cuisine méditerranéenne et ambiance lounge.",
    category: "Mediterranean",
    city: "Marrakech",
    address: "1 Rue du 4 Septembre, Marrakech",
    lat: 31.6250,
    lng: -7.9850,
    phone: "+212524345678",
    email: "contact@comptoirdarna.ma",
    provider_index: 2,
    cuisine_types: ["Mediterranean", "Moroccan"],
    price_range: "$$$",
    table_capacity: 25,
  },
  {
    name: "Ricks Café",
    description: "Restaurant international inspiré du film Casablanca.",
    category: "International",
    city: "Casablanca",
    address: "248 Boulevard Sour Jdid, Casablanca",
    lat: 33.5720,
    lng: -7.5920,
    phone: "+212522567890",
    email: "contact@rickscafe.ma",
    provider_index: 6,
    cuisine_types: ["International", "French"],
    price_range: "$$$",
    table_capacity: 40,
  },
  {
    name: "Dar Moha",
    description: "Cuisine marocaine gastronomique dans un palais.",
    category: "Moroccan",
    city: "Marrakech",
    address: "81 Rue Dar El Bacha, Marrakech",
    lat: 31.6300,
    lng: -7.9900,
    phone: "+212524385678",
    email: "contact@darmoha.ma",
    provider_index: 2,
    cuisine_types: ["Moroccan"],
    price_range: "$$$",
    table_capacity: 20,
  },
  {
    name: "Le Petit Rocher",
    description: "Bistrot français et cuisine du marché.",
    category: "French",
    city: "Rabat",
    address: "56 Avenue Mohammed V, Rabat",
    lat: 34.0250,
    lng: -6.8450,
    phone: "+212537345678",
    email: "info@lepetitrocher.ma",
    provider_index: 1,
    cuisine_types: ["French", "Mediterranean"],
    price_range: "$$",
    table_capacity: 22,
  },
  {
    name: "Ocean View",
    description: "Fruits de mer et poissons frais face à l'océan.",
    category: "Seafood",
    city: "Agadir",
    address: "Promenade de la Plage, Agadir",
    lat: 30.4278,
    lng: -9.5981,
    phone: "+212528823456",
    email: "contact@oceanview.ma",
    provider_index: 5,
    cuisine_types: ["Seafood", "Mediterranean"],
    price_range: "$$",
    table_capacity: 35,
  },
]

# Standard opening hours template
def standard_opening_hours
  {
    "monday" => { "open" => "09:00", "close" => "19:00" },
    "tuesday" => { "open" => "09:00", "close" => "19:00" },
    "wednesday" => { "open" => "09:00", "close" => "19:00" },
    "thursday" => { "open" => "09:00", "close" => "20:00" },
    "friday" => { "open" => "09:00", "close" => "20:00" },
    "saturday" => { "open" => "10:00", "close" => "18:00" },
    "sunday" => { "open" => nil, "close" => nil },
  }
end

businesses = businesses_data.map do |data|
  provider = providers[data[:provider_index]]
  opening_hours = standard_opening_hours

  name_val = data[:name]
  slug_val = "#{name_val} #{data[:city]}".parameterize
  desc_val = data[:description]

  business = provider.businesses.find_or_initialize_by(name: name_val)
  attrs = {
    address: data[:address],
    lat: data[:lat],
    lng: data[:lng],
    phone: data[:phone],
    email: data[:email],
    opening_hours: opening_hours,
  }
  attrs[:category] = data[:category] if Business.column_names.include?("category")
  if data.key?(:cuisine_types) && Business.column_names.include?("cuisine_types")
    attrs[:cuisine_types] =
      data[:cuisine_types]
  end
  attrs[:price_range] = data[:price_range] if data.key?(:price_range) && Business.column_names.include?("price_range")
  if data.key?(:table_capacity) && Business.column_names.include?("table_capacity")
    attrs[:table_capacity] =
      data[:table_capacity]
  end
  business.assign_attributes(attrs)
  business[:city] = data[:city]
  business.city_id = seed_city_for(data[:city])
  business.write_attribute(:categories, [data[:category]].compact) if Business.column_names.include?("categories")
  business[:name] = name_val
  business[:slug] = slug_val
  business[:description] = desc_val
  business.name_en = name_val
  business.name_fr = name_val
  business.name_ar = name_val
  business.slug_en = slug_val
  business.slug_fr = slug_val
  business.slug_ar = slug_val
  business.description_en = desc_val
  business.description_fr = desc_val
  business.description_ar = desc_val
  business.save!
  Rails.logger.debug { "  ✓ Business: #{business.name} (#{business.read_attribute(:city)})" }
  business
end

# Normalize slugs so every business has canonical slug (name + city) for SEO /business/[slug]
businesses.each do |business|
  canonical_slug = business.generate_slug
  next if canonical_slug.blank?

  business.update_columns(slug: canonical_slug)
end

# ============================================================================
# FAKER: 50+ PROVIDERS WITH ALL USE CASES (premium/non-premium, verified/unverified, etc.)
# ============================================================================
if defined?(Faker)
  Rails.logger.debug "\n🎲 Creating 50+ providers with Faker (all use cases)..."

  SEED_CATEGORIES = CANONICAL_CATEGORIES

  faker_providers = []
  faker_businesses = []

  55.times do |i|
    email = "provider#{i + 100}@#{Faker::Internet.domain_name}"
    email = "provider-#{i + 100}-#{SecureRandom.hex(2)}@vazivo-seed.ma" while User.exists?(email: email)

    user = User.find_or_create_by!(email: email) do |u|
      u.name = Faker::Name.name
      u.password = "password123"
      u.role = "provider"
      u.phone = "+2126#{rand(100_000_00..999_999_99)}"
    end

    # Mix: ~85% confirmed, ~15% not confirmed
    user.update!(
      provider_status: rand(1..100) <= 85 ? "confirmed" : "not_confirmed"
    )
    # Premium is set per business when the business is created below (~40% of businesses)

    faker_providers << user
  end
  Rails.logger.debug { "  ✓ Created #{faker_providers.count} Faker provider users (mix confirmed/premium)" }

  faker_providers.each_with_index do |provider, _i|
    city_data = MOROCCAN_CITIES.sample
    city_name = city_data[:name]
    category = SEED_CATEGORIES.sample
    business_name = [
      "Restaurant #{Faker::Name.last_name}",
      "#{Faker::Adjective.positive.capitalize} #{category}",
      "#{Faker::Name.last_name} #{category}",
      "Restaurant #{Faker::Name.first_name}",
      "#{category} #{city_name}",
    ].sample
    business_name = "#{business_name} #{city_name}" if rand(1..100) <= 30
    business_name = business_name.strip[0..199]

    lat = city_data[:lat] + rand(-0.02..0.02)
    lng = city_data[:lng] + rand(-0.02..0.02)
    opening_hours = standard_opening_hours
    # Some with different hours (e.g. closed Sunday/Monday)
    if rand(1..100) <= 25
      opening_hours = opening_hours.merge("sunday" => { "open" => nil, "close" => nil })
      opening_hours = opening_hours.merge("monday" => { "open" => nil, "close" => nil }) if rand(1..2) == 1
    end

    business = provider.businesses.find_or_create_by!(name: business_name) do |b|
      b.write_attribute(:name, business_name)
      b.write_attribute(:slug, "seed-#{business_name.parameterize.presence || 'biz'}-#{SecureRandom.hex(4)}")
      b.description = Faker::Lorem.paragraph(sentence_count: 2)
      b.category = category if Business.column_names.include?("category")
      b.write_attribute(:categories, [category].compact) if Business.column_names.include?("categories")
      b.address = "#{Faker::Address.street_address}, #{city_name}"
      b[:city] = city_name
      b.city_id = seed_city_for(city_name)
      b.lat = lat
      b.lng = lng
      b.phone = "+2125#{rand(20..29)}#{rand(100_000_00..999_999_99)}"
      b.email = Faker::Internet.email(domain: "vazivo-seed.ma")
      b.opening_hours = opening_hours
      b.verification_status = ["verified", "pending"].sample
      if Business.column_names.include?("cuisine_types")
        b.cuisine_types = [category].compact
        b.price_range = ["$", "$$", "$$$"].sample
        b.table_capacity = rand(15..50)
      end
    end
    business.update_columns(verification_status: ["verified", "pending"].sample) if business.persisted?
    # Mix: ~40% premium (per business)
    business.update_column(:premium_expires_at, rand(1..12).months.from_now) if rand(1..100) <= 40
    faker_businesses << business
  end

  faker_businesses.each do |business|
    base_slug = business.generate_slug
    next if base_slug.blank?

    slug = base_slug
    n = 1
    while Business.where(slug_en: slug).where.not(id: business.id).exists?
      slug = "#{base_slug}-#{n}"
      n += 1
    end
    business.update_columns(slug: slug, slug_en: slug)
  end
  Rails.logger.debug do
    "  ✓ Created #{faker_businesses.count} Faker businesses (all cities, categories, verification statuses)"
  end

  # Services for Faker businesses: 0 to 5 per business, linked to subacts (same SEED_ACTS_SUBACTS)
  faker_services_seed = SEED_ACTS_SUBACTS.transform_values do |subacts_data|
    subacts_data.map do |data|
      { **data, price: data[:price] * (0.8 + (rand * 0.4)) }
    end
  end

  faker_businesses.each do |business|
    n_services = rand(0..5)
    next if n_services.zero?

    act_name = seed_business_category(business).presence || "Salon de Beauté"
    subacts_data = faker_services_seed[act_name] || faker_services_seed["Salon de Beauté"]
    next if subacts_data.blank?

    selected = subacts_data.sample([n_services, subacts_data.size].min)
    selected.each do |data|
      subact = find_subact(act_name, data[:name])
      next unless subact

      svc_cat = seed_service_category_for(business, act_name)
      next unless svc_cat

      finder = if Service.column_names.include?("category_id")
                 business.services.find_or_initialize_by(category_id: subact.id)
               else
                 business.services.find_or_initialize_by(name: subact.name)
               end
      finder.tap do |s|
        s.service_category_id = svc_cat.id
        s.category_id = subact.id if s.class.column_names.include?("category_id")
        s.write_attribute(:treatment_type, "service") if s.class.column_names.include?("treatment_type")
        s.name = subact.name
        s.write_attribute(:name, subact.name)
        s.description = data[:description]
        s.duration = data[:duration]
        s.price = data[:price]
        s.save!
      end
    end
  end
  Rails.logger.debug "  ✓ Assigned 0–5 services per Faker business (with category_id)"

  businesses.concat(faker_businesses)
else
  Rails.logger.debug "\n  (Skipping Faker providers: faker gem not loaded)"
end

# ============================================================================
# CREATE SERVICES (linked to sub-categories via category_id)
# ============================================================================
def seed_services_for_business(business, acts_subacts_seed)
  act_name = seed_business_category(business).presence || "Salon de Beauté"
  subacts_data = acts_subacts_seed[act_name] || acts_subacts_seed["Salon de Beauté"]
  return if subacts_data.blank?

  svc_cat = seed_service_category_for(business, act_name)
  return unless svc_cat

  selected = subacts_data.sample([rand(3..5), subacts_data.size].min)
  selected.each do |data|
    subact = find_subact(act_name, data[:name])
    next unless subact

    service = if Service.column_names.include?("category_id")
                business.services.find_or_initialize_by(category_id: subact.id)
              else
                business.services.find_or_initialize_by(name: subact.name)
              end
    service.service_category_id = svc_cat.id
    service.category_id = subact.id if service.class.column_names.include?("category_id")
    service.write_attribute(:treatment_type, "service") if service.class.column_names.include?("treatment_type")
    service.assign_attributes(
      name: subact.name,
      description: data[:description],
      duration: data[:duration],
      price: data[:price]
    )
    service.write_attribute(:name, subact.name)
    next unless service.save

    Rails.logger.debug do
      "  ✓ Service: #{service.name} - #{service.formatted_price} (#{business.name})"
    end
  end
end

Rails.logger.debug "\n💅 Creating services (with category_id → subacts)..."

businesses.each do |business|
  seed_services_for_business(business, SEED_ACTS_SUBACTS)
end

# ============================================================================
# ASSIGN CLOUDINARY URLS FROM MIGRATION MAP (if present)
# ============================================================================
map_path = Rails.root.join("db/cloudinary_migration_map.json")
if File.file?(map_path)
  Rails.logger.debug "\n🖼️  Assigning Cloudinary URLs from map..."
  map = JSON.parse(File.read(map_path))
  categories = map["categories"] || {}
  cities = map["cities"] || {}

  seed_data_helper = Object.new.extend(ProdDataLoadHelpers)
  businesses.each do |business|
    cover = cities[business.read_attribute(:city).to_s] || cities[business.read_attribute(:city).to_s.parameterize] || categories[seed_business_category(business).to_s] || categories[seed_business_category(business).to_s.parameterize]
    next unless cover

    seed_data_helper.attach_business_images_from_urls(business, [cover])
    Rails.logger.debug { "  ✓ Business: #{business.name} -> logo + images (Active Storage)" }
  end

  service_has_image = Service.column_names.include?("image_url")
  if service_has_image
    Service.kept.find_each do |service|
      category = seed_business_category(service.business)
      icon = category && (categories[category] || categories[category.to_s.parameterize])
      if icon
        service.update_column(:image_url, icon)
        Rails.logger.debug { "  ✓ Service: #{service.name} (##{service.id}) -> image_url" }
      end
    end
  end
else
  Rails.logger.debug "\n  (No cloudinary_migration_map.json — run rails cloudinary:migrate_images then re-seed to assign image URLs)"
end

# ============================================================================
# CREATE BOOKINGS
# ============================================================================
Rails.logger.debug "\n📅 Creating bookings..."

# Get some services for bookings
all_services = Service.kept.includes(:business).limit(20)
Business.kept.includes(:services)

# Create past bookings (completed)
# Note: We skip validations for past bookings since they're historical data
Rails.logger.debug "  Creating past bookings..."
past_bookings = []
30.times do |_i|
  service = all_services.sample
  next unless service&.business

  customer = customers.sample
  business = service.business

  # Random date in the past (last 3 months)
  date = rand(90.days.ago..7.days.ago).to_date

  # Random time during business hours
  day_name = date.strftime("%A").downcase
  intervals = business.intervals_for_day(day_name)
  next if intervals.empty?

  # Use first interval for simplicity
  open_time = intervals.first
  start_hour = open_time["open"].split(":").first.to_i
  end_hour = open_time["close"].split(":").first.to_i - 1
  hour = rand(start_hour..end_hour)
  minute = [0, 15, 30, 45].sample

  start_time_str = "#{hour}:#{minute.to_s.rjust(2, '0')}"
  start_time = Time.zone.parse("#{date} #{start_time_str}")
  end_time = start_time + service.duration.minutes
  end_time_str = end_time.strftime("%H:%M")

  # Check if booking already exists (bookings link to services via booking_services, not a service column)
  existing = Booking.joins(:booking_service_items).where(
    user_id: customer.id,
    business_id: business.id,
    date: date,
    start_time: start_time_str
  ).where(booking_services: { service_id: service.id }).first

  if existing
    past_bookings << existing
    next
  end

  # Create booking skipping validations for past dates
  booking = Booking.new(
    user: customer,
    business: business,
    date: date,
    start_time: start_time_str,
    end_time: end_time_str,
    total_price: service.price,
    status: :completed,
    completed_at: start_time + service.duration.minutes
  )
  # short_booking_id is NOT NULL; set explicitly when saving with validate: false (callback may not run)
  booking.short_booking_id = loop do
    id = SecureRandom.hex(4).upcase
    break id unless Booking.exists?(short_booking_id: id)
  end

  # Skip validations that don't apply to historical data
  booking.save(validate: false)

  BookingServiceItem.create!(
    booking_id: booking.id,
    service_id: service.id,
    staff_id: business.user_id,
    price: service.price,
    duration_minutes: service.duration,
    position: 0
  )
  past_bookings << booking
end
Rails.logger.debug { "  ✓ Created #{past_bookings.count} past bookings" }

# Create upcoming bookings
Rails.logger.debug "  Creating upcoming bookings..."
upcoming_bookings = []
20.times do |_i|
  service = all_services.sample
  next unless service&.business

  customer = customers.sample
  business = service.business

  # Random date in the future (next 30 days)
  date = rand((Time.zone.today + 1)..(Time.zone.today + 30))

  # Random time during business hours
  day_name = date.strftime("%A").downcase
  intervals = business.intervals_for_day(day_name)
  next if intervals.empty?

  # Use first interval for simplicity
  open_time = intervals.first
  open_hour = open_time["open"].split(":").first.to_i
  close_hour = open_time["close"].split(":").first.to_i

  # Calculate the latest possible start time accounting for service duration
  # Service duration is in minutes, convert to hours (rounded up)
  service_hours = (service.duration / 60.0).ceil
  latest_start_hour = close_hour - service_hours

  # Skip if service duration is longer than available hours
  next if latest_start_hour < open_hour

  hour = rand(open_hour..latest_start_hour)
  minute = [0, 15, 30, 45].sample

  # Ensure the booking end time doesn't exceed closing time
  start_time = Time.zone.parse("#{date} #{hour}:#{minute.to_s.rjust(2, '0')}")
  end_time = start_time + service.duration.minutes
  close_time = Time.zone.parse("#{date} #{open_time['close']}")

  # Skip if end time would exceed closing time
  next if end_time > close_time

  start_time_str = start_time.strftime("%H:%M")
  end_time_str = end_time.strftime("%H:%M")
  # Skip if this service already has an active booking in this slot
  overlapping = Booking.joins(:booking_service_items)
    .where(booking_services: { service_id: service.id }, date: date)
    .where.not(status: [:cancelled, :no_show])
    .where("start_time < ? AND end_time > ?", end_time_str, start_time_str)
  next if overlapping.exists?

  statuses = [:pending, :confirmed]
  status = statuses.sample

  booking = Booking.create!(
    user: customer,
    business: business,
    date: date,
    start_time: start_time_str,
    end_time: end_time_str,
    total_price: service.price,
    status: status,
    confirmed_at: (status == :confirmed ? Time.current : nil),
    number_of_guests: Booking.column_names.include?("number_of_guests") ? rand(1..6) : nil
  )

  BookingServiceItem.create!(
    booking_id: booking.id,
    service_id: service.id,
    staff_id: business.user_id,
    price: service.price,
    duration_minutes: service.duration,
    position: 0
  )
  upcoming_bookings << booking
end
Rails.logger.debug { "  ✓ Created #{upcoming_bookings.count} upcoming bookings" }

# ============================================================================
# CREATE REVIEWS
# ============================================================================
Rails.logger.debug "\n⭐ Creating reviews..."

review_comments = [
  "Service excellent, je recommande vivement !",
  "Très satisfait du service, personnel professionnel.",
  "Expérience agréable, je reviendrai certainement.",
  "Service de qualité, prix raisonnable.",
  "Personnel accueillant et compétent.",
  "Excellent rapport qualité-prix.",
  "Service impeccable, je suis très content.",
  "Très bon service, ambiance agréable.",
  "Je recommande ce salon, service professionnel.",
  "Service correct mais peut être amélioré.",
  "Bonne expérience globale, à refaire.",
  "Service rapide et efficace.",
  "Personnel très professionnel et à l'écoute.",
  "Service de qualité supérieure.",
  "Très satisfait, je reviendrai bientôt.",
]

past_bookings.sample(rand(15..past_bookings.count)).each do |booking|
  next if booking.review.present?

  rating = rand(3..5) # Mostly positive reviews
  comment = review_comments.sample

  Review.create!(
    booking: booking,
    business: booking.business,
    user: booking.user,
    rating: rating,
    comment: comment,
    cleanliness_rating: rating,
    punctuality_rating: rating,
    professionalism_rating: rating,
    service_quality_rating: rating,
    hygiene_rating: rating
  )
  Rails.logger.debug { "  ✓ Review: #{rating}⭐ for #{booking.business.name}" }
end

# ============================================================================
# CREATE PAYMENTS
# ============================================================================
Rails.logger.debug "\n💳 Creating payments..."

# Create booking payments for completed bookings
past_bookings.each do |booking|
  next if booking.booking_payment.present?

  BookingPayment.create!(
    booking: booking,
    user: booking.user,
    amount: booking.total_price,
    currency: "mad",
    status: :succeeded,
    paid_at: booking.completed_at || Time.zone.parse("#{booking.date} #{booking.start_time}")
  )
  Rails.logger.debug { "  ✓ Booking payment: #{booking.total_price} MAD for #{booking.business.name}" }
end

# Create booking payments for some confirmed upcoming bookings
upcoming_bookings.select(&:status_confirmed?).sample(5).each do |booking|
  next if booking.booking_payment.present?

  BookingPayment.create!(
    booking: booking,
    user: booking.user,
    amount: booking.total_price,
    currency: "mad",
    status: :pending,
    paid_at: nil
  )
  Rails.logger.debug { "  ✓ Booking payment (pending): #{booking.total_price} MAD for #{booking.business.name}" }
end

# ============================================================================
# PLANS (subscription plans assignable when upgrading providers)
# ============================================================================
Rails.logger.debug "\n📦 Ensuring default plan..."
Plan.find_or_create_by!(identifier: "premium_monthly") do |p|
  p.write_attribute(:name, "Premium Monthly")
  p.name = "Premium Monthly"
  p.duration_months = 1
  p.suggested_price = 0
  p.currency = "mad"
  p.active = true
  p.position = 0
end
Rails.logger.debug "  ✓ Plan: Premium Monthly (premium_monthly)"

# ============================================================================
# SUMMARY
# ============================================================================
Rails.logger.debug { "\n#{'=' * 60}" }
Rails.logger.debug "✅ Seeding completed successfully!"
Rails.logger.debug "=" * 60
Rails.logger.debug "\n📊 Statistics:"
Rails.logger.debug do
  "  👥 Users: #{User.count} (#{User.admins.count} admins, #{User.providers.count} providers, #{User.customers.count} customers)"
end
Rails.logger.debug { "  🏢 Businesses: #{Business.count} across #{Business.distinct.pluck(:city).count} cities" }
Rails.logger.debug { "  💅 Services: #{Service.count}" }
Rails.logger.debug { "  📅 Bookings: #{Booking.count} (#{Booking.past.count} past, #{Booking.upcoming.count} upcoming)" }
Rails.logger.debug { "  ⭐ Reviews: #{Review.count}" }
Rails.logger.debug { "  💳 Booking payments: #{BookingPayment.count}" }
Rails.logger.debug "\n🔑 Demo Accounts:"
Rails.logger.debug "  Admin:    admin@ollazen.ma / password123"
Rails.logger.debug "  Provider: fatima@ollazen.ma / password123"
Rails.logger.debug "  Customer: sara@ollazen.ma / password123"
Rails.logger.debug "\n📍 Cities covered:"
MOROCCAN_CITIES.each { |city| Rails.logger.debug "  • #{city[:name]}" }
Rails.logger.debug "=" * 60
