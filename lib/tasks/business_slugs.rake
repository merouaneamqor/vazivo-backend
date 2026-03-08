# frozen_string_literal: true

namespace :businesses do
  desc "Normalize business slugs to match current generate_slug (name + city). Run after seeds or when slugs are out of sync."
  task normalize_slugs: :environment do
    total = 0
    normalized = 0
    Business.kept.find_each do |b|
      total += 1
      new_slug = b.generate_slug
      if new_slug.blank?
        warn "  [skip] #{b.name} (id=#{b.id}): generate_slug returned blank"
        next
      end
      old_slug = b.slug
      b.update_columns(slug: new_slug)
      if old_slug != new_slug
        normalized += 1
        puts "  #{b.name} (#{b.city}): #{old_slug} -> #{new_slug}"
      end
    end
    puts "Processed #{total}, normalized #{normalized} business slug(s)."
  end
end
