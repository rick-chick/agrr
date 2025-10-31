# frozen_string_literal: true

module Agrr
  class FertilizeGateway < BaseGatewayV2
    # List popular fertilizers
    def list(language:, limit: 5, area: nil)
      Rails.logger.info "🌾 [AGRR] Fetching fertilizer list: language=#{language}, limit=#{limit}, area=#{area}"
      
      result = execute_command(
        'dummy_path', # Not used in V2
        'fertilize', 'list',
        '--language', language,
        '--limit', limit.to_s,
        *(['--area', area.to_s] if area),
        '--json'
      )
      
      Rails.logger.info "✅ [AGRR] Fertilizer list fetched: #{result.is_a?(Array) ? result.count : 'unknown'} items"
      result
    end
    
    # Get detailed fertilizer information
    def get(name:)
      Rails.logger.info "🔍 [AGRR] Fetching fertilizer details: name=#{name}"
      
      result = execute_command(
        'dummy_path', # Not used in V2
        'fertilize', 'get',
        '--name', name,
        '--json'
      )
      
      Rails.logger.info "✅ [AGRR] Fertilizer details fetched successfully"
      result
    end
    
    # Recommend fertilizer plan
    def recommend(crop_file:)
      Rails.logger.info "💡 [AGRR] Generating fertilizer recommendation: crop_file=#{crop_file}"
      
      result = execute_command(
        'dummy_path', # Not used in V2
        'fertilize', 'recommend',
        '--crop-file', crop_file,
        '--json'
      )
      
      Rails.logger.info "✅ [AGRR] Fertilizer recommendation generated successfully"
      result
    end
  end
end

