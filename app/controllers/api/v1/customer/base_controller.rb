# frozen_string_literal: true

module Api
  module V1
    module Customer
      class BaseController < ApplicationController
        # Customer controllers - authentication handled per controller
        # Some actions (like create booking) may be public
      end
    end
  end
end
