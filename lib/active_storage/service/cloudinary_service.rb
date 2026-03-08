# frozen_string_literal: true

# Active Storage adapter for Cloudinary. For server-side uploads from provider controllers
# (e.g. business logo/images), the same flow as prod import is used: CloudinaryUploader.upload
# plus ProdDataLoadHelpers (attach_logo_from_url / attach_images_from_urls). This service
# is used when Active Storage is configured with storage :cloudinary and attachments
# are uploaded via AS (e.g. attach(io: ...)).
require "cloudinary"

module ActiveStorage
  class Service::CloudinaryService < Service
    def initialize(cloud_name:, api_key:, api_secret:, secure: true, folder: nil, **options)
      @cloud_name = cloud_name
      @api_key = api_key
      @api_secret = api_secret
      @secure = secure
      @folder = folder
      @options = options

      Cloudinary.config do |config|
        config.cloud_name = cloud_name
        config.api_key = api_key
        config.api_secret = api_secret
        config.secure = secure
      end
    end

    def upload(key, io, checksum: nil, content_type: nil, disposition: nil, filename: nil, **)
      instrument :upload, key: key, checksum: checksum do
        options = {
          public_id: public_id_for(key),
          resource_type: resource_type_for(content_type),
          overwrite: true,
        }
        options[:folder] = @folder if @folder

        Cloudinary::Uploader.upload(io, options)
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          stream(key, &block)
        end
      else
        instrument :download, key: key do
          uri = URI(url(key, expires_in: 30.minutes))
          Net::HTTP.get(uri)
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        uri = URI(url(key, expires_in: 30.minutes))
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri)
          request["Range"] = "bytes=#{range.begin}-#{range.end}"
          http.request(request).body
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        Cloudinary::Uploader.destroy(public_id_for(key))
      rescue Cloudinary::Api::Error
        # Ignore if file doesn't exist
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        Cloudinary::Api.delete_resources_by_prefix(prefixed_key(prefix))
      rescue Cloudinary::Api::Error
        # Ignore if files don't exist
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        result = Cloudinary::Api.resource(public_id_for(key))
        payload[:exist] = result.present?
        result.present?
      rescue Cloudinary::Api::NotFound
        payload[:exist] = false
        false
      end
    end

    def url(key, expires_in: nil, disposition: nil, filename: nil, content_type: nil, **)
      instrument :url, key: key do |payload|
        # Use :image so URLs use /image/upload/; :auto produces /auto/upload/ which can return 400.
        url = Cloudinary::Utils.cloudinary_url(
          public_id_for(key),
          resource_type: :image,
          secure: @secure
        )
        payload[:url] = url
        url
      end
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, **)
      instrument :url, key: key do |payload|
        # Cloudinary doesn't support traditional direct uploads via signed URLs
        # Return the upload endpoint instead
        timestamp = Time.current.to_i
        Cloudinary::Utils.api_sign_request(
          { timestamp: timestamp, public_id: public_id_for(key) },
          @api_secret
        )

        url = "https://api.cloudinary.com/v1_1/#{@cloud_name}/auto/upload"
        payload[:url] = url
        url
      end
    end

    def headers_for_direct_upload(_key, content_type:, checksum:, **)
      { "Content-Type" => content_type }
    end

    private

    def public_id_for(key)
      @folder ? "#{@folder}/#{key}" : key.to_s
    end

    def prefixed_key(prefix)
      @folder ? "#{@folder}/#{prefix}" : prefix.to_s
    end

    def resource_type_for(content_type)
      case content_type
      when %r{^image/}
        :image
      when %r{^video/}
        :video
      else
        :raw
      end
    end

    def stream(key, &block)
      uri = URI(url(key, expires_in: 30.minutes))
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          response.read_body(&block)
        end
      end
    end
  end
end
