# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      # GET entry_schedule/crops/:id — 参照農場・参照作物・予測気象に基づくエントリ詳細（単一ユースケース）
      class EntryScheduleShowInteractor
        def initialize(output_port:, crop_gateway:, weather_loader:, optimization_runner:, translator:, clock:)
          @output_port = output_port
          @crop_gateway = crop_gateway
          @weather_loader = weather_loader
          @optimization_runner = optimization_runner
          @translator = translator
          @clock = clock
        end

        # @param farm [Farm] 参照農場（controller 事前検証済み）
        # @param crop [Crop] 参照作物（CropFindReferenceForEntryScheduleInteractor 成功時）
        # @param reference_date [Date] 予測終了日未指定時の基準日（エッジで注入）
        # @param prediction_end_date_raw [String, nil]
        def call(farm:, crop:, reference_date:, prediction_end_date_raw:)
          payload_hash = @weather_loader.load_prediction_payload!(
            farm: farm,
            prediction_end_date_raw: prediction_end_date_raw,
            reference_date: reference_date
          )

          result = @optimization_runner.call(
            crop: crop,
            weather_payload: payload_hash,
            farm: farm,
            crop_gateway: @crop_gateway
          )
          crop_stages = @crop_gateway.list_crop_stages_by_crop_id(crop.id)
          crop_detail = Domain::PublicPlan::Mappers::EntryScheduleCropMapper.crop_detail(
            crop,
            result,
            translator: @translator,
            crop_stages: crop_stages,
            clock: @clock
          )
          prediction_meta = Domain::PublicPlan::Mappers::EntryScheduleCropMapper.prediction_meta(
            farm: farm,
            payload_hash: payload_hash,
            chart_calendar_year: reference_date.year
          )
          farm_fragment = {
            id: farm.id,
            name: farm.name,
            latitude: farm.latitude,
            longitude: farm.longitude,
            region: farm.region
          }
          dto = Dtos::EntryScheduleShowOutput.new(
            farm_fragment: farm_fragment,
            prediction_fragment: prediction_meta,
            crop_fragment: crop_detail
          )
          @output_port.on_success(dto)
        rescue Domain::PublicPlan::Exceptions::WeatherLocationMissingError
          @output_port.on_failure(Dtos::EntryScheduleFailure.weather_location_required)
        rescue Domain::PublicPlan::Exceptions::PredictionPayloadMissingError
          @output_port.on_failure(Dtos::EntryScheduleFailure.prediction_payload_missing)
        rescue Domain::PublicPlan::Exceptions::WeatherPredictionFailedError => e
          @output_port.on_failure(Dtos::EntryScheduleFailure.weather_prediction_failed(e.message))
        end
      end
    end
  end
end
