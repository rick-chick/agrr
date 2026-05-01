# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # 参照農場気象 × 作物 1 件のエントリ詳細 JSON ペイロード（公開 show / マイ作物 schedule 共通）（T-035）。
      class EntryScheduleShowPayload
        class WeatherLocationMissingError < StandardError; end
        class PredictionPayloadMissingError < StandardError; end
        class WeatherPredictionFailedError < StandardError; end

        def self.call(farm:, crop:, prediction_end_date: nil)
          new(farm: farm, crop: crop, prediction_end_date: prediction_end_date).call
        end

        def initialize(farm:, crop:, prediction_end_date: nil)
          @farm = farm
          @crop = crop
          @prediction_end_date = prediction_end_date
        end

        def call
          payload_hash = load_or_predict_weather!
          prediction_meta = EntryScheduleResponseBuilder.prediction_meta(farm: @farm, payload_hash: payload_hash)
          result = Adapters::Agrr::EntryScheduleOptimizationGateway.call(
            crop: @crop,
            weather_payload: payload_hash,
            farm: @farm,
            crop_gateway: CompositionRoot.crop_gateway
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
          raise WeatherLocationMissingError if @farm.weather_location.blank?

          target_end = parse_prediction_end_date
          service = CompositionRoot.weather_prediction_interactor(weather_location: @farm.weather_location, farm: @farm)

          cached = service.get_existing_prediction(target_end_date: target_end)
          payload_hash = if cached && cached[:data].is_a?(Hash)
                           cached[:data]
          else
                           service.predict_for_farm(target_end_date: target_end)
                           @farm.reload
                           @farm.predicted_weather_data
          end

          raise PredictionPayloadMissingError if payload_hash.blank? || payload_hash["data"].blank?

          payload_hash
        rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
               Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
          raise WeatherPredictionFailedError, e.message
        end

        def parse_prediction_end_date
          raw = @prediction_end_date
          return Date.current.end_of_year if raw.blank?

          Date.parse(raw.to_s)
        rescue ArgumentError
          Date.current.end_of_year
        end
      end
    end
  end
end
