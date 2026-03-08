# frozen_string_literal: true

class SearchService
  # When H3 location search radius is at or above this (km), treat as "very large" region (e.g. country)
  LARGE_REGION_RADIUS_KM = 200
  # For very large regions, only show businesses with average rating >= this
  LARGE_REGION_MIN_RATING = 4.7

  def initialize(params = {}, base_scope: nil)
    # In Rails 7.1+, ActionController::Parameters already supports indifferent access
    @params = params
    @base_scope = base_scope
  end

  def search_businesses
    scope = @base_scope || Business.kept

    # Text search
    scope = scope.search(@params[:q]) if @params[:q].present?

    # Category filter
    scope = scope.by_category(@params[:category]) if @params[:category].present?

    # City filter
    scope = scope.by_city(@params[:city]) if @params[:city].present?

    # Price range filter
    if @params[:min_price].present? || @params[:max_price].present?
      min_price = @params[:min_price] || 0
      max_price = @params[:max_price] || Float::INFINITY
      scope = scope.by_price_range(min_price, max_price)
    end

    # Rating filter (user-defined; may be overridden for large regions below)
    scope = apply_rating_filter(scope) if @params[:min_rating].present?

    # Location filter (if lat/lng provided)
    location_radius_km = nil
    if @params[:lat].present? && @params[:lng].present?
      radius = @params[:radius] || 10
      location_radius_km = radius.to_f
      scope = filter_by_distance(scope, @params[:lat], @params[:lng], radius)
    end

    # Very large region (e.g. country): show only best-rated businesses
    force_sort_by_rating = false
    if location_radius_km && location_radius_km >= LARGE_REGION_RADIUS_KM
      effective_min = [@params[:min_rating].to_f, LARGE_REGION_MIN_RATING].max
      scope = apply_rating_filter_with(scope, effective_min) if effective_min.positive?
      force_sort_by_rating = true
    end

    # Sorting - returns [scope, needs_grouping]
    scope, needs_grouping = apply_sorting(scope, force_sort_by: force_sort_by_rating ? "rating" : nil)

    # Use preload for eager loading - it runs separate queries and avoids GROUP BY conflicts
    # Only eager load if we don't have GROUP BY, otherwise load after pagination
    if needs_grouping
      # When we have GROUP BY, don't eager load to avoid conflicts
      # The associations will be loaded separately by the controller if needed
      scope
    else
      scope.preload(:user, :services, :reviews)
    end
  end

  def search_services
    scope = Service.kept.includes(:business)
    scope = scope.joins(:business).merge(Business.kept)

    # Text search
    if @params[:q].present?
      scope = scope.where("services.name ILIKE ? OR services.description ILIKE ?",
                          "%#{@params[:q]}%", "%#{@params[:q]}%")
    end

    # Business filter
    scope = scope.where(business_id: @params[:business_id]) if @params[:business_id].present?

    # Price range
    scope = scope.by_price_range(@params[:min_price], @params[:max_price])

    # Duration range
    scope.by_duration_range(@params[:min_duration], @params[:max_duration])
  end

  private

  def apply_rating_filter(scope)
    min_rating = @params[:min_rating].to_f
    apply_rating_filter_with(scope, min_rating)
  end

  def apply_rating_filter_with(scope, min_rating)
    return scope if min_rating <= 0

    business_ids = Review.group(:business_id)
      .having("AVG(rating) >= ?", min_rating)
      .pluck(:business_id)

    scope.where(id: business_ids)
  end

  def filter_by_distance(scope, lat, lng, radius_km)
    hex_indexes = Business.h3_hex_indexes_for_radius(lat.to_f, lng.to_f, radius_km.to_f)
    return scope.none if hex_indexes.empty?

    scope.where(h3_index: hex_indexes)
  end

  def apply_sorting(scope, force_sort_by: nil)
    sort_by = force_sort_by.presence || @params[:sort_by]
    premium_first = premium_first_order
    case sort_by
    when "rating"
      # Only select businesses.* to avoid GROUP BY conflicts
      [scope.select("businesses.*")
        .left_joins(:reviews)
        .group("businesses.id")
        .order(premium_first)
        .order(Arel.sql("AVG(reviews.rating) DESC NULLS LAST")), true]
    when "price_low"
      # Use subquery for price sorting to avoid GROUP BY issues
      min_price_subquery = Service.kept
        .joins(:business)
        .merge(Business.kept)
        .select("business_id, MIN(price) as min_price")
        .group("business_id")
        .to_sql

      [scope.select("businesses.*")
        .joins(Arel.sql("LEFT JOIN (#{min_price_subquery}) AS price_stats ON price_stats.business_id = businesses.id"))
        .order(premium_first)
        .order(Arel.sql("price_stats.min_price ASC NULLS LAST")), false]
    when "price_high"
      # Use subquery for price sorting to avoid GROUP BY issues
      max_price_subquery = Service.kept
        .joins(:business)
        .merge(Business.kept)
        .select("business_id, MAX(price) as max_price")
        .group("business_id")
        .to_sql

      [scope.select("businesses.*")
        .joins(Arel.sql("LEFT JOIN (#{max_price_subquery}) AS price_stats ON price_stats.business_id = businesses.id"))
        .order(premium_first)
        .order(Arel.sql("price_stats.max_price DESC NULLS LAST")), false]
    when "newest"
      [scope.select("businesses.*").order(premium_first).order(created_at: :desc), false]
    when "name"
      [scope.select("businesses.*").order(premium_first).order(name: :asc), false]
    else
      # Default: by rating then name
      # Only select businesses.* to avoid GROUP BY conflicts
      [scope.select("businesses.*")
        .left_joins(:reviews)
        .group("businesses.id")
        .order(premium_first)
        .order(Arel.sql("AVG(reviews.rating) DESC NULLS LAST"), name: :asc), true]
    end
  end

  # Premium businesses first (order by business premium_expires_at)
  def premium_first_order
    Arel.sql("businesses.premium_expires_at DESC NULLS LAST")
  end
end
