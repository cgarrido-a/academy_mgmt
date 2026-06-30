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

  # Use production credentials only when running in production AND both
  # production credentials are actually present. This prevents silently
  # sending blank credentials to Transbank if an ENV var is missing.
  def self.use_production?
    Rails.env.production? && PRODUCTION_COMMERCE_CODE.present? && PRODUCTION_API_KEY.present?
  end

  def self.commerce_code
    use_production? ? PRODUCTION_COMMERCE_CODE : INTEGRATION_COMMERCE_CODE
  end

  def self.api_key
    use_production? ? PRODUCTION_API_KEY : INTEGRATION_API_KEY
  end

  def self.base_url
    use_production? ? PRODUCTION_BASE_URL : INTEGRATION_BASE_URL
  end

  def self.environment
    use_production? ? :production : :integration
  end
end

Rails.logger.info "Transbank configuration loaded for #{TransbankConfig.environment} environment"
if Rails.env.production? && !TransbankConfig.use_production?
  Rails.logger.warn "Transbank: running in Rails production but FALLING BACK to integration " \
                    "credentials (TRANSBANK_COMMERCE_CODE / TRANSBANK_API_KEY missing or blank)."
end
