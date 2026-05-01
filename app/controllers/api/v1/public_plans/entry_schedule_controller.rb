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
          presenter = Presenters::Api::PublicPlans::ReferenceFarmsPresenter.new(view: self)
          Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)
        end

        # GET .../public_plans/entry_schedule/crops?farm_id=&prediction_end_date=&limit=&cursor=
        def crops
          farm = find_reference_farm!
          payload_hash = load_or_predict_weather!(farm)
          prediction_meta = Domain::PublicPlan::Services::EntryScheduleResponseBuilder.prediction_meta(
            farm: farm,
            payload_hash: payload_hash,
            chart_calendar_year: Date.current.year
          )

          items = []
          presenter = Presenters::Api::PublicPlans::EntryScheduleReferenceCropsPresenter.new(view: self)
          Domain::Crop::Interactors::CropListReferenceForEntryScheduleInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(farm.region)
          return if performed?

          @reference_crops.each do |crop|
            result = Adapters::Agrr::EntryScheduleOptimizationGateway.call(
              crop: crop,
              weather_payload: payload_hash,
              farm: farm,
              crop_gateway: CompositionRoot.crop_gateway
            )
            items << Domain::PublicPlan::Services::EntryScheduleResponseBuilder.crop_list_item(
              crop,
              result,
              translator: CompositionRoot.translator,
              clock: Time.zone
            )
          end

          items.sort_by! { |it| Domain::PublicPlan::Services::EntryScheduleResponseBuilder.sort_tuple_for_list_item(it) }

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
          presenter = Presenters::Api::PublicPlans::EntryScheduleReferenceCropPresenter.new(view: self)
          Domain::Crop::Interactors::CropFindReferenceForEntryScheduleInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(farm.region, params[:id])
          return if performed?

          crop = @reference_crop
          reference_date = Date.current
          presenter = Presenters::Api::PublicPlans::EntryScheduleShowPresenter.new(view: self)
          CompositionRoot.entry_schedule_show_interactor(output_port: presenter, clock: Time.zone).call(
            farm: farm,
            crop: crop,
            reference_date: reference_date,
            prediction_end_date_raw: params[:prediction_end_date].presence
          )
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
          reference_date = Date.current
          Presenters::Api::PublicPlans::EntrySchedulePredictedWeather.load_or_predict!(
            farm: farm,
            prediction_end_date_raw: params[:prediction_end_date].presence,
            reference_date: reference_date
          ) do |f|
            CompositionRoot.weather_prediction_interactor(weather_location: f.weather_location, farm: f)
          end
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

        rescue_from Domain::PublicPlan::Exceptions::WeatherLocationMissingError do
          render json: {
            error: I18n.t("api.entry_schedule.errors.weather_location_required"),
            error_key: "api.entry_schedule.errors.weather_location_required"
          }, status: :unprocessable_entity
        end

        rescue_from Domain::PublicPlan::Exceptions::PredictionPayloadMissingError do
          render json: {
            error: I18n.t("api.errors.common.no_weather_data"),
            error_key: "api.errors.common.no_weather_data"
          }, status: :unprocessable_entity
        end

        rescue_from Domain::PublicPlan::Exceptions::WeatherPredictionFailedError do |e|
          render json: {
            error: e.message,
            error_key: "api.entry_schedule.errors.prediction_failed"
          }, status: :service_unavailable
        end
      end
    end
  end
end
