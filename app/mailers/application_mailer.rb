# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_SENDER", "Vazivo <contact@vazivo.com>")
  layout "mailer"
end
