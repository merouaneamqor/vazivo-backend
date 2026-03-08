# frozen_string_literal: true

# Prevents delivery to prod_data seed users (@seed.ollazen.ma, @seed.glow.ma) so we never send real emails
# to fake provider accounts (protects sender reputation and avoids bounces).
class ProdDataSeedEmailInterceptor
  def self.delivering_email(mail)
    return unless any_recipient_seed?(mail)

    mail.perform_deliveries = false
    Rails.logger.info "[ProdDataSeedEmailInterceptor] Skipping delivery to seed address(es); recipients included #{ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS.join(', ')}"
  end

  def self.any_recipient_seed?(mail)
    collect_emails(mail).any? { |addr| ProdDataLoadHelpers.seed_email?(addr) }
  end

  def self.collect_emails(mail)
    [mail.to, mail.cc, mail.bcc].flat_map { |field| Array.wrap(field) }.map do |addr|
      raw = addr.respond_to?(:address) ? addr.address : addr.to_s
      raw.to_s.strip
    end.compact
  end
end
