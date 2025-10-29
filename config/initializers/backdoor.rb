# frozen_string_literal: true

# Backdoor configuration for AGRR daemon status monitoring
# This allows remote status checking with environment variable token authentication

module BackdoorConfig
  # Get backdoor token from environment variable
  # Set AGRR_BACKDOOR_TOKEN environment variable to enable this feature
  def self.token
    ENV['AGRR_BACKDOOR_TOKEN']
  end
  
  # Check if backdoor is enabled (token is configured)
  def self.enabled?
    token.present?
  end
end

