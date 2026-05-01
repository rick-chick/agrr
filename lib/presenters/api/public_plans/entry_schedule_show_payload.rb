# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # 参照農場気象 × 作物 1 件のエントリ詳細 JSON の組み立て（公開 show / マイ作物 schedule 共通）（T-035）。
      # クラス名は Payload のままだが、気象の取得・Agrr 最適化呼び出しまで含む API エッジ向けオーケストレーション。
      class EntryScheduleShowPayload
        class WeatherLocationMissingError < StandardError; end
        class PredictionPayloadMissingError < StandardError; end
        class WeatherPredictionFailedError < StandardError; end

        # @param farm [Farm] 参照農場（+weather_location+ 必須。未設定時は WeatherLocationMissingError）
        # @param crop [Crop]
        # @param crop_gateway [Object] CompositionRoot.crop_gateway 相当（EntryScheduleOptimizationGateway 向け）
        # @param reference_date [Date] 予測終了日未指定時の基準日（コントローラで Date.current を渡す）
        # @param prediction_end_date [String, nil] 上限日の生文字列（任意）
        # @yield [farm] #get_existing_prediction / #predict_for_farm を持つ WeatherPredictionInteractor（遅延生成用）
        def self.call(farm:, crop:, crop_gateway:, reference_date:, prediction_end_date: nil)
          raise WeatherLocationMissingError if farm.weather_location.blank?

          weather_prediction_service = yield(farm)

          new(
            farm: farm,
            crop: crop,
            crop_gateway: crop_gateway,
            weather_prediction_service: weather_prediction_service,
            reference_date: reference_date,
            prediction_end_date: prediction_end_date
          ).call
        end

        # @param reference_date [Date] 予測終了日未指定時の基準日（エッジで注入）
        def initialize(farm:, crop:, crop_gateway:, weather_prediction_service:, reference_date:, prediction_end_date: nil)
          @farm = farm
          @crop = crop
          @crop_gateway = crop_gateway
          @weather_prediction_service = weather_prediction_service
          @reference_date = reference_date
          @prediction_end_date = prediction_end_date
        end

        def call
          payload_hash = load_or_predict_weather!
          prediction_meta = EntryScheduleResponseBuilder.prediction_meta(farm: @farm, payload_hash: payload_hash)
          result = Adapters::Agrr::EntryScheduleOptimizationGateway.call(
            crop: @crop,
            weather_payload: payload_hash,
            farm: @farm,
            crop_gateway: @crop_gateway
          )
          detail = EntryScheduleResponseBuilder.crop_detail(@crop, result)

          {
            farm: @farm.as_json(only: %i[id name latitude longitude region]),
            prediction: prediction_meta,
            crop: detail
          }
        end

        private

        def load_or_predict_weather!
          EntrySchedulePredictedWeather.load_or_predict!(
            farm: @farm,
            prediction_end_date_raw: @prediction_end_date,
            reference_date: @reference_date
          ) { |_| @weather_prediction_service }
        end
      end
    end
  end
end
