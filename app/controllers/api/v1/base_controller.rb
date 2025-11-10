module Api
  module V1
    class BaseController < ApplicationController
      # Disable CSRF protection for API requests
      skip_before_action :verify_authenticity_token
    end
  end
end
