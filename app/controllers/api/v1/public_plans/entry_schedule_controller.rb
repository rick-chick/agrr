# frozen_string_literal: true

require "base64"

module Api
  module V1
    module PublicPlans
      # 作物スケジュール（エントリ）— 参照農場・参照作物・予測気象に基づく植え/まき帯
      class EntryScheduleController < ApplicationController
        include EntryScheduleJsonRendering

        skip_before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        before_action :apply_entry_locale

        # GET .../public_plans/entry_schedule/farms
        def farms
          region = params[:region].presence || locale_to_region(I18n.locale)
          farms = Domain::Farm::Gateways::FarmGateway.default.reference_records(region: region)
          render json: farms.as_json(only: %i[id name latitude longitude region])
        end

        # GET .../public_plans/entry_schedule/crops?farm_id=&prediction_end_date=&limit=&cursor=
        def crops
          farm = find_reference_farm!
          payload_hash = load_or_predict_weather!(farm)
          prediction_meta = Presenters::Api::PublicPlans::EntryScheduleResponseBuilder.prediction_meta(farm: farm, payload_hash: payload_hash)

          crop_scope = Domain::Crop::Gateways::CropGateway.default
                       .reference_records(region: farm.region)
                       .includes(crop_stages: :temperature_requirement)
                       .order(:name)
          items = []
          crop_scope.find_each do |crop|
            result = Adapters::Agrr::EntryScheduleOptimizationGateway.call(crop: crop, weather_payload: payload_hash, farm: farm)
            items << Presenters::Api::PublicPlans::EntryScheduleResponseBuilder.crop_list_item(crop, result)
          end

          items.sort_by! { |it| Presenters::Api::PublicPlans::EntryScheduleResponseBuilder.sort_tuple_for_list_item(it) }

          total_count = items.size
          limit = parse_entry_limit
          offset = decode_entry_cursor(params[:cursor])
          offset = 0 if offset.nil? || offset.negative?
          offset = total_count if offset > total_count
          page_items = items[offset, limit] || []
          next_offset = offset + page_items.size
          has_more = next_offset < total_count
          next_cursor = has_more ? encode_entry_cursor(next_offset) : nil

          payload = {
            farm: farm.as_json(only: %i[id name latitude longitude region]),
            prediction: prediction_meta,
            meta: {
              total_count: total_count,
              limit: limit,
              next_cursor: next_cursor,
              has_more: has_more
            },
            crops: page_items
          }

          render_entry_json_with_etag(payload)
        end

        # GET .../public_plans/entry_schedule/crops/:id?farm_id=
        def show
          farm = find_reference_farm!
          crop = Domain::Crop::Gateways::CropGateway.default
                 .reference_records(region: farm.region)
                 .includes(crop_stages: :temperature_requirement)
                 .find(params[:id])
          payload = Presenters::Api::PublicPlans::EntryScheduleShowPayload.call(
            farm: farm,
            crop: crop,
            prediction_end_date: params[:prediction_end_date].presence
          )
          render_entry_json_with_etag(payload)
        end

        private

        def parse_entry_limit
          raw = params[:limit]
          return 20 if raw.blank?

          [ [ raw.to_i, 1 ].max, 50 ].min
        end

        def encode_entry_cursor(offset)
          Base64.urlsafe_encode64({ o: offset }.to_json)
        end

        def decode_entry_cursor(raw)
          return nil if raw.blank?

          json = JSON.parse(Base64.urlsafe_decode64(raw))
          Integer(json["o"])
        rescue ArgumentError, JSON::ParserError, TypeError
          nil
        end

        def find_reference_farm!
          raise ActiveRecord::RecordNotFound, "farm_id is required" if params[:farm_id].blank?

          farm = Farm.find(params[:farm_id])
          raise ActiveRecord::RecordNotFound, "not a reference farm" unless farm.reference?

          farm
        end

        # 手順・前提の固定ドキュメント: docs/planning/crop_schedule_entry_weather_initialization.md
        #
        # @return [Hash] predicted_weather_data 形式（トップレベルに data 配列）
        def load_or_predict_weather!(farm)
          raise Presenters::Api::PublicPlans::EntryScheduleShowPayload::WeatherLocationMissingError if farm.weather_location.blank?

          target_end = parse_prediction_end_date
          service = Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(weather_location: farm.weather_location, farm: farm)

          cached = service.get_existing_prediction(target_end_date: target_end)
          payload_hash = if cached && cached[:data].is_a?(Hash)
                           cached[:data]
          else
                           service.predict_for_farm(target_end_date: target_end)
                           farm.reload
                           farm.predicted_weather_data
          end

          raise Presenters::Api::PublicPlans::EntryScheduleShowPayload::PredictionPayloadMissingError if payload_hash.blank? || payload_hash["data"].blank?

          payload_hash
        rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
               Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
          raise Presenters::Api::PublicPlans::EntryScheduleShowPayload::WeatherPredictionFailedError, e.message
        end

        def parse_prediction_end_date
          raw = params[:prediction_end_date].presence
          return Date.current.end_of_year if raw.blank?

          Date.parse(raw.to_s)
        rescue ArgumentError
          Date.current.end_of_year
        end

        def apply_entry_locale
          loc = params[:locale].presence
          loc ||= extract_locale_from_accept_language_header if respond_to?(:extract_locale_from_accept_language_header, true)
          loc = I18n.default_locale if loc.blank?
          loc = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(loc.to_s)
          I18n.locale = loc.to_sym
        end

        def locale_to_region(locale)
          case locale.to_s
          when "ja" then "jp"
          when "us" then "us"
          when "in" then "in"
          else "jp"
          end
        end

        rescue_from ActiveRecord::RecordNotFound do |e|
          render json: { error: e.message, error_key: "api.errors.common.farm_not_found" }, status: :not_found
        end

        rescue_from Presenters::Api::PublicPlans::EntryScheduleShowPayload::WeatherLocationMissingError do
          render json: {
            error: I18n.t("api.entry_schedule.errors.weather_location_required"),
            error_key: "api.entry_schedule.errors.weather_location_required"
          }, status: :unprocessable_entity
        end

        rescue_from Presenters::Api::PublicPlans::EntryScheduleShowPayload::PredictionPayloadMissingError do
          render json: {
            error: I18n.t("api.errors.common.no_weather_data"),
            error_key: "api.errors.common.no_weather_data"
          }, status: :unprocessable_entity
        end

        rescue_from Presenters::Api::PublicPlans::EntryScheduleShowPayload::WeatherPredictionFailedError do |e|
          render json: {
            error: e.message,
            error_key: "api.entry_schedule.errors.prediction_failed"
          }, status: :service_unavailable
        end
      end
    end
  end
end
