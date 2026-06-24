require 'transbank/sdk'

# Transbank Webpay Configuration
#
# Development/test use Transbank's public integration credentials.
# Production reads from Rails encrypted credentials. Expected structure:
#
#   transbank:
#     commerce_code: <your production commerce code>
#     api_key: <your production api key>
#
# Edit with: rails credentials:edit --environment production
# Decrypted at runtime via RAILS_MASTER_KEY (or config/credentials/production.key).

module TransbankConfig
  INTEGRATION_COMMERCE_CODE = '597055555532'
  INTEGRATION_API_KEY = '579B532A7440BB0C9079DED94D31EA1615BACEB56610332264630D42D0A36B1C'
  INTEGRATION_BASE_URL = 'https://webpay3gint.transbank.cl'
  PRODUCTION_BASE_URL = 'https://webpay3g.transbank.cl'

  def self.commerce_code
    return INTEGRATION_COMMERCE_CODE unless Rails.env.production?

    Rails.application.credentials.dig(:transbank, :commerce_code) ||
      raise('Missing transbank.commerce_code in production credentials')
  end

  def self.api_key
    return INTEGRATION_API_KEY unless Rails.env.production?

    Rails.application.credentials.dig(:transbank, :api_key) ||
      raise('Missing transbank.api_key in production credentials')
  end

  def self.base_url
    Rails.env.production? ? PRODUCTION_BASE_URL : INTEGRATION_BASE_URL
  end

  def self.environment
    Rails.env.production? ? :production : :integration
  end
end

Rails.logger.info "Transbank configuration loaded for #{TransbankConfig.environment} environment"
