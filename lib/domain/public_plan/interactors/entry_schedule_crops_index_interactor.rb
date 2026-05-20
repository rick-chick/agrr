# frozen_string_literal: true

require "base64"

module Domain
  module PublicPlan
    module Interactors
      # GET entry_schedule/crops — 参照農場・予測気象・参照作物の一覧（単一ユースケース）
      class EntryScheduleCropsIndexInteractor
        def initialize(output_port:, weather_loader:, crop_gateway:, optimization_runner:, translator:, clock:, logger:)
          @output_port = output_port
          @weather_loader = weather_loader
          @crop_gateway = crop_gateway
          @optimization_runner = optimization_runner
          @translator = translator
          @clock = clock
          @logger = logger
        end

        # @param farm [Farm] 参照農場（事前解決済み）
        def call(farm:, prediction_end_date_raw:, limit:, offset:, reference_date:)
          payload_hash = @weather_loader.load_prediction_payload!(
            farm: farm,
            prediction_end_date_raw: prediction_end_date_raw,
            reference_date: reference_date
          )

          prediction_meta = Domain::PublicPlan::Mappers::EntryScheduleCropMapper.prediction_meta(
            farm: farm,
            payload_hash: payload_hash,
            chart_calendar_year: reference_date.year
          )

          items = build_crop_list_items(farm, payload_hash)
          items.sort_by! { |it| Domain::PublicPlan::Mappers::EntryScheduleCropMapper.sort_tuple_for_list_item(it) }

          total_count = items.size
          offset = 0 if offset.nil? || offset.negative?
          offset = total_count if offset > total_count
          page_items = items[offset, limit] || []
          next_offset = offset + page_items.size
          has_more = next_offset < total_count

          payload = {
            farm: farm.as_json(only: %i[id name latitude longitude region]),
            prediction: prediction_meta,
            meta: {
              total_count: total_count,
              limit: limit,
              next_cursor: has_more ? encode_cursor(next_offset) : nil,
              has_more: has_more
            },
            crops: page_items
          }

          @output_port.on_success(payload)
        rescue Domain::PublicPlan::Exceptions::WeatherLocationMissingError
          @output_port.on_failure(Dtos::EntryScheduleFailure.weather_location_required)
        rescue Domain::PublicPlan::Exceptions::PredictionPayloadMissingError
          @output_port.on_failure(Dtos::EntryScheduleFailure.prediction_payload_missing)
        rescue Domain::PublicPlan::Exceptions::WeatherPredictionFailedError => e
          @output_port.on_failure(Dtos::EntryScheduleFailure.weather_prediction_failed(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("[EntryScheduleCropsIndexInteractor] RecordInvalid: #{e.message}")
          @output_port.on_failure(Dtos::EntryScheduleFailure.internal_error(e.message))
        end

        private

        def build_crop_list_items(farm, payload_hash)
          items = []
          @crop_gateway.each_reference_crop_for_entry_schedule(farm.region) do |crop|
            result = @optimization_runner.call(
              crop: crop,
              weather_payload: payload_hash,
              farm: farm,
              crop_gateway: @crop_gateway
            )
            items << Domain::PublicPlan::Mappers::EntryScheduleCropMapper.crop_list_item(
              crop,
              result,
              translator: @translator,
              clock: @clock
            )
          end
          items
        end

        def encode_cursor(offset)
          Base64.urlsafe_encode64({ o: offset }.to_json)
        end
      end
    end
  end
end
