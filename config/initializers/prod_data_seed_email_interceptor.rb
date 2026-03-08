# frozen_string_literal: true

# Prevent sending any email to prod_data seed users (@seed.ollazen.ma, @seed.glow.ma) to protect sender reputation.
require Rails.root.join("app", "mailers", "prod_data_seed_email_interceptor")
Rails.application.config.action_mailer.register_interceptor(ProdDataSeedEmailInterceptor)
