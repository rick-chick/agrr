# frozen_string_literal: true

module Agrr
  class PredictionGateway < BaseGateway
    def predict(historical_data:, days:)
      Rails.logger.info "🔮 [AGRR] Predicting weather for #{days} days"
      
      input_file = write_temp_file(historical_data, prefix: 'weather_input')
      output_file = Tempfile.new(['weather_output', '.json'])
      
      begin
        execute_command(
          agrr_path,
          'predict',
          '--input', input_file.path,
          '--output', output_file.path,
          '--days', days.to_s,
          parse_json: false
        )
        
        # 出力ファイルからJSONを読み込む
        output_file.rewind
        output_content = output_file.read
        
        if output_content.empty?
          Rails.logger.error "❌ [AGRR] Output file is empty"
          raise ParseError, "Prediction output file is empty"
        end
        
        result = JSON.parse(output_content)
        Rails.logger.info "✅ [AGRR] Prediction completed: #{result['data']&.count || 0} records"
        result
      rescue JSON::ParserError => e
        Rails.logger.error "❌ [AGRR] Failed to parse prediction output: #{e.message}"
        Rails.logger.error "Output content: #{output_content&.first(200)}"
        raise ParseError, "Failed to parse prediction output: #{e.message}"
      ensure
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end
    end
  end
end

