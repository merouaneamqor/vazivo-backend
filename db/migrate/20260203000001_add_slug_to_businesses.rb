class AddSlugToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :slug, :string
    add_index :businesses, :slug, unique: true

    # Backfill existing records with slugs
    reversible do |dir|
      dir.up do
        Business.reset_column_information

        used_slugs = Set.new

        Business.find_each do |business|
          # Generate base slug from name and city
          base_slug = "#{business.name} #{business.city}".parameterize
          slug = base_slug
          counter = 1

          # Ensure uniqueness
          while used_slugs.include?(slug)
            slug = "#{base_slug}-#{counter}"
            counter += 1
          end

          used_slugs.add(slug)
          business.update_column(:slug, slug)
        end
      end
    end
  end
end
