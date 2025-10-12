# frozen_string_literal: true

module Agrr
  class WeatherGateway < BaseGateway
    def fetch(latitude:, longitude:, days:)
      Rails.logger.info "🌤️  [AGRR] Fetching weather: lat=#{latitude}, lon=#{longitude}, days=#{days}"
      
      result = execute_command(
        agrr_path,
        'weather',
        '--location', "#{latitude},#{longitude}",
        '--days', days.to_s,
        '--json'
      )
      
      Rails.logger.info "✅ [AGRR] Weather data fetched: #{result['data']&.count || 0} records"
      result
    end
  end
end

