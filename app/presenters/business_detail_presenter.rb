# frozen_string_literal: true

class BusinessDetailPresenter < BusinessPresenter
  def as_json(*)
    stats = stats_json
    super.merge(
      today_hours: today_hours,
      updated_at: business.updated_at,
      owner: owner_info,
      premium: business.premium?,
      services: services_json,
      reviews: reviews_json,
      stats: stats,
      staff: staff_json,
      rating_breakdown: stats[:rating_breakdown],
      category_averages: stats[:category_averages]
    )
  end

  delegate :today_hours, to: :business

  def owner_info
    return nil unless business.user

    {
      id: business.user_id,
      name: business.user&.name.to_s.presence || "—",
    }
  end

  def services_json
    business.services.kept.includes(:service_category, { category: :parent }).map do |s|
      ServicePresenter.new(s).as_json
    end
  end

  def reviews_json
    business.reviews.approved.recent.limit(10).map { |r| ReviewPresenter.new(r).as_json }
  end

  def stats_json
    approved_reviews = business.reviews.approved
    total = approved_reviews.count

    rating_breakdown = if total.positive?
                         (1..5).to_h do |rating|
                           count = approved_reviews.where(rating: rating).count
                           [rating, { count: count, percentage: (count.to_f / total * 100).round(1) }]
                         end
                       else
                         {}
                       end

    category_averages = if total.positive?
                          Review::CORE_CATEGORIES.to_h do |category|
                            avg = approved_reviews.average("#{category}_rating").to_f.round(2)
                            [category, avg]
                          end.merge(
                            Review::PREMIUM_CATEGORIES.to_h do |category|
                              avg = approved_reviews.where.not("#{category}_rating": nil).average("#{category}_rating").to_f.round(2)
                              [category, avg]
                            end
                          )
                        else
                          {}
                        end

    {
      services_count: business.services.kept.count,
      reviews_count: total_reviews,
      average_rating: average_rating,
      rating_breakdown: rating_breakdown,
      category_averages: category_averages,
    }
  end

  def staff_json
    business.business_staff.active.includes(:user).order(Arel.sql("CASE role WHEN 'owner' THEN 0 ELSE 1 END")).map do |bs|
      user = bs.user
      {
        id: user.id,
        name: user.name,
        avatar_url: user.avatar&.url,
      }
    end
  end
end
