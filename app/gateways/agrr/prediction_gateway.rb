# frozen_string_literal: true

module Agrr
  class PredictionGateway < BaseGateway
    def predict(historical_data:, days:)
      Rails.logger.info "🔮 [AGRR] Predicting weather for #{days} days"
      
      input_file = write_temp_file(historical_data, prefix: 'weather_input')
      
      begin
        result = execute_command(
          agrr_path,
          'predict',
          '--input', input_file.path,
          '--days', days.to_s,
          '--format', 'json'
        )
        
        Rails.logger.info "✅ [AGRR] Prediction completed: #{result['data']&.count || 0} records"
        result
      ensure
        input_file.close
        input_file.unlink
      end
    end
  end
end

