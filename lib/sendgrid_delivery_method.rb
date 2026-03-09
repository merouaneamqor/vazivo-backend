# frozen_string_literal: true

require "sendgrid-ruby"

class SendgridDeliveryMethod
  include SendGrid

  def initialize(settings)
    @api_key = settings[:api_key] || ENV.fetch("SENDGRID_API_KEY", nil)
    Rails.logger.info("SendGrid API Key present: #{@api_key.present?}, length: #{@api_key&.length}")
  end

  def deliver!(mail)
    # Never send to prod_data seed users (protects sender reputation)
    to_addresses = Array.wrap(mail.to).map { |a| a.respond_to?(:address) ? a.address : a.to_s }.compact
    if to_addresses.any? { |addr| ProdDataLoadHelpers.seed_email?(addr) }
      Rails.logger.info "[SendgridDeliveryMethod] Skipping send to seed address(es); to=#{to_addresses.join(', ')}"
      return
    end

    sg = SendGrid::API.new(api_key: @api_key)

    from = SendGrid::Email.new(email: mail.from.first)
    to = SendGrid::Email.new(email: mail.to.first)
    subject = mail.subject

    # Handle multipart emails
    body = if mail.multipart?
             mail.html_part ? mail.html_part.body.decoded : mail.text_part.body.decoded
           else
             mail.body.decoded
           end

    # Determine content type
    content_type = if mail.multipart? && mail.html_part
                     "text/html"
                   elsif mail.content_type&.include?("html")
                     "text/html"
                   else
                     "text/plain"
                   end

    content = SendGrid::Content.new(type: content_type, value: body)

    personalization = SendGrid::Personalization.new
    personalization.add_to(to)

    sg_mail = SendGrid::Mail.new
    sg_mail.from = from
    sg_mail.subject = subject
    sg_mail.add_content(content)
    sg_mail.add_personalization(personalization)

    response = sg.client.mail._("send").post(request_body: sg_mail.to_json)

    return if response.status_code.to_i == 202

    raise "SendGrid API error: #{response.status_code} - #{response.body}"
  end
end
