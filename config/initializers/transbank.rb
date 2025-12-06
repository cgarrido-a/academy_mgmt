require 'transbank/sdk'

# Transbank Webpay Configuration
#
# This file defines configuration constants that will be used throughout the application
# when making calls to the Transbank API.
#
# For production, you need to:
# 1. Register at https://www.transbankdevelopers.cl/
# 2. Get your commerce code and API key
# 3. Set environment variables: TRANSBANK_COMMERCE_CODE and TRANSBANK_API_KEY

module TransbankConfig
  # Integration/Test credentials (default for development)
  INTEGRATION_COMMERCE_CODE = '597055555532'
  INTEGRATION_API_KEY = '579B532A7440BB0C9079DED94D31EA1615BACEB56610332264630D42D0A36B1C'
  INTEGRATION_BASE_URL = 'https://webpay3gint.transbank.cl'

  # Production credentials (from environment variables)
  PRODUCTION_COMMERCE_CODE = ENV['TRANSBANK_COMMERCE_CODE']
  PRODUCTION_API_KEY = ENV['TRANSBANK_API_KEY']
  PRODUCTION_BASE_URL = 'https://webpay3g.transbank.cl'

  def self.commerce_code
    # TEMPORARY: Force integration credentials for testing
    # TODO: Remove this and use production credentials when ready
    INTEGRATION_COMMERCE_CODE
    # Rails.env.production? ? PRODUCTION_COMMERCE_CODE : INTEGRATION_COMMERCE_CODE
  end

  def self.api_key
    # TEMPORARY: Force integration credentials for testing
    # TODO: Remove this and use production credentials when ready
    INTEGRATION_API_KEY
    # Rails.env.production? ? PRODUCTION_API_KEY : INTEGRATION_API_KEY
  end

  def self.base_url
    # TEMPORARY: Force integration URL for testing
    # TODO: Remove this and use production URL when ready
    INTEGRATION_BASE_URL
    # Rails.env.production? ? PRODUCTION_BASE_URL : INTEGRATION_BASE_URL
  end

  def self.environment
    # TEMPORARY: Force integration environment for testing
    # TODO: Remove this and use production when ready
    :integration
    # Rails.env.production? ? :production : :integration
  end
end

Rails.logger.info "Transbank configuration loaded for #{TransbankConfig.environment} environment"
