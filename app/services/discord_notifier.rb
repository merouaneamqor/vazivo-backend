# frozen_string_literal: true

# Sends messages to a Discord channel via webhook.
# Set DISCORD_WEBHOOK_URL in the environment (from Discord: Server Settings → Integrations → Webhooks).
# No-op when URL is blank.
class DiscordNotifier
  class << self
    # Send a plain text message (max 2000 chars).
    # @param content [String]
    # @return [Boolean] true if sent, false if skipped or failed
    def notify(content)
      return false if webhook_url.blank?

      body = { content: content.to_s[0..1999] }
      post(body)
    end

    # Send an embed (title, description, optional fields and color).
    # @param title [String]
    # @param description [String, nil]
    # @param fields [Array<Hash>] e.g. [{ name: "Field", value: "Value", inline: true }]
    # @param color [Integer, nil] decimal color (e.g. 0x00ff00 = 65280 for green)
    # @return [Boolean]
    def notify_embed(title:, description: nil, fields: [], color: nil)
      return false if webhook_url.blank?

      embed = { title: title.to_s[0..255] }
      embed[:description] = description.to_s[0..4095] if description.present?
      if fields.any?
        embed[:fields] = fields.first(25).map do |f|
          { name: f[:name].to_s[0..256], value: f[:value].to_s[0..1023], inline: f[:inline] != false }
        end
      end
      embed[:color] = color if color.present?
      embed[:timestamp] = Time.current.iso8601

      post({ embeds: [embed] })
    end

    def webhook_url
      ENV["DISCORD_WEBHOOK_URL"].to_s.presence
    end

    private

    def post(body)
      uri = URI(webhook_url)
      Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json")
      true
    rescue StandardError => e
      Rails.logger.warn("[DiscordNotifier] webhook failed: #{e.message}")
      false
    end
  end
end
