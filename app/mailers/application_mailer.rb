# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_SENDER', 'Ollazen <contact@ollazen.com>')
  layout "mailer"
end
