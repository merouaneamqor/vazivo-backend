# Example: Adding CarrierWave profile photos to a model

This example shows how to use the Imageable concern to add CarrierWave-based profile photos with automatic Cloudinary transformations.

## Usage

1. Include the Imageable concern
2. Call `has_profile_photos` with field names
3. Upload files via `model.field_name = uploaded_file`
4. Access versions via `model.field_name.version.url`

## Model example

```ruby
class ExampleModel < ApplicationRecord
  include Imageable

  # Mount ImageUploader for these fields
  # This gives you automatic versions: standard (800x600), thumbnail (120x120)
  has_profile_photos :avatar, :cover_photo

  # Now you can use:
  # - example.avatar = params[:file]
  # - example.avatar.url (original)
  # - example.avatar.standard.url (800x600)
  # - example.avatar.thumbnail.url (120x120)
end
```

## Controller example

```ruby
class ExampleController < ApplicationController
  def update
    @example = ExampleModel.find(params[:id])

    # Upload profile photo
    if params[:avatar].present?
      @example.avatar = params[:avatar]
    end

    if @example.save
      render json: {
        avatar_url: @example.avatar.url,
        avatar_thumbnail: @example.avatar.thumbnail.url,
        avatar_standard: @example.avatar.standard.url
      }
    else
      render json: { errors: @example.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
```

## Gallery images (multiple images)

Use the ImagesController approach: `POST /api/v1/provider/businesses/:business_id/images` for more control and to get `public_id` for each image.
