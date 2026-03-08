# frozen_string_literal: true

# Only run when letter_opener gem is loaded (development). In production/test the gem
# is not in the bundle, so LetterOpener is undefined and this would raise NameError.
Rails.application.config.after_initialize do
  next unless defined?(LetterOpener)

  # In Docker/headless there is no browser, so Launchy.open raises. Rescue so the
  # request succeeds; email is already written to tmp/letter_opener.
  require "launchy"

  LetterOpener::DeliveryMethod.class_eval do
    alias_method :original_deliver_bang, :deliver!

    define_method :deliver! do |mail|
      original_deliver_bang(mail)
    rescue Launchy::CommandNotFoundError, Launchy::Error
      # no-op
    end
  end
end
