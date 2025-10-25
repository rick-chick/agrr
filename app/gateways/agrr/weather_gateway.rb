# frozen_string_literal: true

module Agrr
  class WeatherGateway < BaseGatewayV2
    def fetch(latitude:, longitude:, days:)
      Rails.logger.info "🌤️  [AGRR] Fetching weather: lat=#{latitude}, lon=#{longitude}, days=#{days}"
      
      result = execute_command(
        'dummy_path', # Not used in V2
        'weather',
        '--location', "#{latitude},#{longitude}",
        '--days', days.to_s,
        '--data-source', 'jma',
        '--json'
      )
      
      Rails.logger.info "✅ [AGRR] Weather data fetched: #{result['data']&.count || 0} records"
      result
    end
  end
end

