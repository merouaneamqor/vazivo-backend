# frozen_string_literal: true

namespace :cloudinary do
  desc "Migrate all existing image URLs/attachments to Cloudinary; write mapping to db/cloudinary_migration_map.json"
  task migrate_images: :environment do
    unless defined?(Cloudinary) && Cloudinary.config.api_key.present?
      puts "Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET."
      next
    end

    map_path = Rails.root.join("db/cloudinary_migration_map.json")
    mapping = if File.file?(map_path)
                JSON.parse(File.read(map_path))
              else
                { "categories" => {}, "cities" => {}, "businesses" => {}, "services" => {}, "users" => {},
                  "entries" => [] }
              end
    mapping["entries"] ||= []

    # --- Categories (seed mapping: name/slug -> URL) ---
    category_sources = {
      "Beauty & Wellness" => "https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400&q=80",
      "Barber" => "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400&q=80",
      "Fitness" => "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80",
    }
    category_sources.each do |name, url|
      next if mapping["categories"]&.[](name).to_s.include?("res.cloudinary.com")

      slug = name.parameterize
      folder = CloudinaryPathBuilder.category_folder(slug)
      begin
        result = CloudinaryUploader.upload(url, folder: folder)
        next unless result

        secure_url = result[:secure_url]
        mapping["categories"] ||= {}
        mapping["categories"][name] = secure_url
        mapping["categories"][slug] = secure_url
        mapping["entries"] << { model: "category", id: slug, attribute: "icon_url", old_url: url,
                                new_public_id: result[:public_id], new_url: secure_url }
        puts "  [category] #{name} -> #{secure_url}"
      rescue StandardError => e
        puts "  [category] #{name} ERROR: #{e.message}"
      end
    end

    # --- Cities (seed mapping) ---
    city_sources = {
      "Casablanca" => "https://images.unsplash.com/photo-1558642452-9d2a7deb7f62?w=800&q=80",
      "Rabat" => "https://images.unsplash.com/photo-1549140602-2ae56fc7e4bf?w=800&q=80",
      "Marrakech" => "https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=800&q=80",
      "Fes" => "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80",
      "Tangier" => "https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=800&q=80",
      "Agadir" => "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80",
      "Meknes" => "https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80",
      "Oujda" => "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800&q=80",
      "Kenitra" => "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80",
      "Tetouan" => "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&q=80",
    }
    city_sources.each do |name, url|
      next if mapping["cities"]&.[](name).to_s.include?("res.cloudinary.com")

      slug = name.parameterize
      folder = "cities/#{slug}/gallery"
      begin
        result = CloudinaryUploader.upload(url, folder: folder)
        next unless result

        secure_url = result[:secure_url]
        mapping["cities"] ||= {}
        mapping["cities"][name] = secure_url
        mapping["cities"][slug] = secure_url
        mapping["entries"] << { model: "city", id: slug, attribute: "photo_url", old_url: url,
                                new_public_id: result[:public_id], new_url: secure_url }
        puts "  [city] #{name} -> #{secure_url}"
      rescue StandardError => e
        puts "  [city] #{name} ERROR: #{e.message}"
      end
    end

    # --- Businesses: cover_image_url, gallery_urls, logo (attachments) ---
    Business.kept.find_each do |business|
      # Cover / gallery URLs: if not Cloudinary, upload and update
      cover = business.cover_image_url
      if cover.present? && cover.to_s.exclude?("res.cloudinary.com")
        begin
          folder = CloudinaryPathBuilder.business_cover_folder(business.id)
          result = CloudinaryUploader.upload(cover, folder: folder)
          if result
            business.update_columns(cover_image_url: result[:secure_url])
            mapping["entries"] << { model: "Business", id: business.id, attribute: "cover_image_url", old_url: cover,
                                    new_public_id: result[:public_id], new_url: result[:secure_url] }
            puts "  [business #{business.id}] cover_image_url -> Cloudinary"
          end
        rescue StandardError => e
          puts "  [business #{business.id}] cover_image_url ERROR: #{e.message}"
        end
      end

      gallery = business.gallery_urls.is_a?(Array) ? business.gallery_urls : []
      new_gallery = gallery.map do |url|
        next url if url.to_s.include?("res.cloudinary.com")

        begin
          folder = CloudinaryPathBuilder.business_gallery_folder(business.id)
          result = CloudinaryUploader.upload(url, folder: folder)
          result ? result[:secure_url] : url
        rescue StandardError => e
          puts "  [business #{business.id}] gallery_url ERROR: #{e.message}"
          url
        end
      end
      business.update_columns(gallery_urls: new_gallery) if new_gallery != gallery

      # Logo attachment -> upload to Cloudinary and set logo_url if we add column; for now we keep attachment, optional: upload and set a new column
      next unless business.logo.attached?

      blob = business.logo.blob
      begin
        folder = CloudinaryPathBuilder.business_cover_folder(business.id)
        Tempfile.open([blob.filename.base, blob.filename.extension_with_delimiter]) do |tmp|
          tmp.binmode
          tmp.write(blob.download)
          tmp.rewind
          result = CloudinaryUploader.upload(tmp, folder: folder)
          if result
            mapping["entries"] << { model: "Business", id: business.id, attribute: "logo", old_url: "attachment",
                                    new_public_id: result[:public_id], new_url: result[:secure_url] }
            puts "  [business #{business.id}] logo (attachment) -> Cloudinary"
            # Business has no logo_url column; keep attachment or add column in migration; skip update for now
          end
        end
      rescue StandardError => e
        puts "  [business #{business.id}] logo ERROR: #{e.message}"
      end
    end

    # --- Services: image_url, image attachment ---
    Service.kept.find_each do |service|
      url = service.image_url.presence
      if url.present? && url.to_s.exclude?("res.cloudinary.com")
        begin
          folder = CloudinaryPathBuilder.service_folder(service.id)
          result = CloudinaryUploader.upload(url, folder: folder)
          if result
            service.update_column(:image_url, result[:secure_url])
            mapping["entries"] << { model: "Service", id: service.id, attribute: "image_url", old_url: url,
                                    new_public_id: result[:public_id], new_url: result[:secure_url] }
            puts "  [service #{service.id}] image_url -> Cloudinary"
          end
        rescue StandardError => e
          puts "  [service #{service.id}] image_url ERROR: #{e.message}"
        end
      end

      next unless service.image.attached?

      blob = service.image.blob
      begin
        folder = CloudinaryPathBuilder.service_folder(service.id)
        Tempfile.open([blob.filename.base, blob.filename.extension_with_delimiter]) do |tmp|
          tmp.binmode
          tmp.write(blob.download)
          tmp.rewind
          result = CloudinaryUploader.upload(tmp, folder: folder)
          if result
            service.update_column(:image_url, result[:secure_url])
            mapping["entries"] << { model: "Service", id: service.id, attribute: "image", old_url: "attachment",
                                    new_public_id: result[:public_id], new_url: result[:secure_url] }
            puts "  [service #{service.id}] image (attachment) -> Cloudinary"
          end
        end
      rescue StandardError => e
        puts "  [service #{service.id}] image ERROR: #{e.message}"
      end
    end

    # --- Users: avatar attachment (optional avatar_url column not present; we just upload and log) ---
    User.kept.find_each do |user|
      next unless user.avatar.attached?

      blob = user.avatar.blob
      begin
        folder = CloudinaryPathBuilder.user_avatar_folder(user.id)
        Tempfile.open([blob.filename.base, blob.filename.extension_with_delimiter]) do |tmp|
          tmp.binmode
          tmp.write(blob.download)
          tmp.rewind
          result = CloudinaryUploader.upload(tmp, folder: folder)
          if result
            mapping["entries"] << { model: "User", id: user.id, attribute: "avatar", old_url: "attachment",
                                    new_public_id: result[:public_id], new_url: result[:secure_url] }
            puts "  [user #{user.id}] avatar -> Cloudinary (store URL in avatar_url if column exists)"
            # user.update_column(:avatar_url, result[:secure_url]) if user.respond_to?(:avatar_url=)
          end
        end
      rescue StandardError => e
        puts "  [user #{user.id}] avatar ERROR: #{e.message}"
      end
    end

    File.write(map_path, JSON.pretty_generate(mapping))
    puts "\n✓ Mapping saved to #{map_path}"
  end
end
