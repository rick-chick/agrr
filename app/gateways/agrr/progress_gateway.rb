# frozen_string_literal: true

module Agrr
  class ProgressGateway < BaseGatewayV2
    # agrr progress コマンドを実行して作物の成長進捗を計算
    # @param crop [Crop] 作物モデル
    # @param start_date [Date] 栽培開始日
    # @param weather_data [Hash] 気象データ
    # @return [Hash] 成長進捗データ
    def calculate_progress(crop:, start_date:, weather_data:)
      Rails.logger.info "📊 [AGRR Progress] Calculating progress: crop=#{crop.name}, start=#{start_date}"
      
      # Cropモデルから作物プロファイルを生成
      crop_requirement = crop.to_agrr_requirement
      crop_file = write_temp_file(crop_requirement, prefix: 'crop_profile')
      weather_file = write_temp_file(weather_data, prefix: 'weather')
      
      # デバッグ用にファイルを保存（本番環境以外のみ）
      unless Rails.env.production?
        debug_dir = Rails.root.join('tmp/debug')
        FileUtils.mkdir_p(debug_dir)
        debug_crop_path = debug_dir.join("progress_crop_#{Time.current.to_i}.json")
        debug_weather_path = debug_dir.join("progress_weather_#{Time.current.to_i}.json")
        FileUtils.cp(crop_file.path, debug_crop_path)
        FileUtils.cp(weather_file.path, debug_weather_path)
        Rails.logger.info "📁 [AGRR Progress] Debug crop saved to: #{debug_crop_path}"
        Rails.logger.info "📁 [AGRR Progress] Debug weather saved to: #{debug_weather_path}"
      end
      
      begin
        command_args = [
          'dummy_path', # Not used in V2
          'progress',
          '--crop-file', crop_file.path,
          '--start-date', start_date.to_s,
          '--weather-file', weather_file.path,
          '--format', 'json'
        ]
        
        result = execute_command(*command_args)
        
        Rails.logger.info "✅ [AGRR Progress] Calculation completed: #{result['daily_progress']&.count} days"
        
        result
      ensure
        crop_file.close
        crop_file.unlink
        weather_file.close
        weather_file.unlink
      end
    end
  end
end

