# frozen_string_literal: true

class PredictionChannel < ApplicationCable::Channel
  def subscribed
    farm = Farm.find_by(id: params[:farm_id])

    if farm
      stream_name = "prediction:#{farm.to_gid_param}"
      stream_from stream_name

      Rails.logger.info "✅ [PredictionChannel#subscribed] Farm##{farm.id} subscribed to #{stream_name}"

      # 既に予測データがある場合は即座に通知
      if farm.predicted_weather_data.present? && farm.predicted_weather_data["data"].present?
        transmit({
          type: "prediction_ready",
          farm_id: farm.id,
          data_count: farm.predicted_weather_data["data"].count,
          prediction_start_date: farm.predicted_weather_data["prediction_start_date"],
          prediction_end_date: farm.predicted_weather_data["prediction_end_date"]
        })
      end
    else
      Rails.logger.error "❌ [PredictionChannel#subscribed] Farm not found: #{params[:farm_id]}"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "👋 [PredictionChannel#unsubscribed] Farm##{params[:farm_id]}"
  end
end
