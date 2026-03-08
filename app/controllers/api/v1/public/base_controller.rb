# frozen_string_literal: true

module Api
  module V1
    module Public
      class BaseController < ApplicationController
        # Public controllers - no authentication required by default
      end
    end
  end
end
