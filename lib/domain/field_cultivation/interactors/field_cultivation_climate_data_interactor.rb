# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        include Concerns::PlanFieldCultivationAuthorization

        def initialize(
          output_port:,
          logger:,
          user_id:,
          user_lookup:,
          climate_source_gateway:,
          crop_gateway:,
          weather_data_gateway:,
          weather_prediction_gateway:,
          prediction_gateway:,
          cultivation_plan_gateway:,
          anchors_resolver:,
          climate_progress_gateway:,
          crop_agrr_requirement_builder:,
          clock:,
          translator:
        )
          @output_port = output_port
          @logger = logger
          @user_id = user_id
          @user_lookup = user_lookup
          @climate_source_gateway = climate_source_gateway
          @crop_gateway = crop_gateway
          @weather_data_gateway = weather_data_gateway
          @weather_prediction_gateway = weather_prediction_gateway
          @prediction_gateway = prediction_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @anchors_resolver = anchors_resolver
          @climate_progress_gateway = climate_progress_gateway
          @crop_agrr_requirement_builder = crop_agrr_requirement_builder
          @clock = clock
          @translator = translator
        end

        def call(input_dto)
          user_dto = @user_id.present? ? @user_lookup.find(@user_id) : nil

          field_cultivation_id = input_dto.field_cultivation_id
          plan_access_snapshot = @climate_source_gateway.find_plan_access_snapshot_by_field_cultivation_id(
            field_cultivation_id
          )
          if user_dto
            assert_field_cultivation_plan_access!(user_dto, plan_access_snapshot)
          else
            assert_public_field_cultivation_plan_access!(plan_access_snapshot)
          end

          source = @climate_source_gateway.find_climate_source_snapshot_by_field_cultivation_id(
            field_cultivation_id
          )
          assert_climate_preconditions!(source)

          crop_entity = resolve_crop_entity(source: source, user_dto: user_dto)
          raise Domain::Shared::Exceptions::RecordNotFound, crop_not_found_message unless crop_entity

          context = Mappers::FieldCultivationClimateContextSnapshotMapper.to_context_snapshot(
            source: source,
            crop: crop_entity
          )

          climate_data = assemble_climate_data(
            source: source,
            context: context,
            crop_entity: crop_entity,
            display_start_date: input_dto.display_start_date,
            display_end_date: input_dto.display_end_date
          )

          if climate_data.nil?
            @logger.warn("[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id=#{input_dto.field_cultivation_id}")
            @output_port.on_error(
              Domain::Shared::Dtos::Error.new("Field cultivation climate data not found")
            )
            return
          end

          filtered_data = apply_display_range(climate_data, input_dto.display_start_date, input_dto.display_end_date)
          @output_port.present(filtered_data)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_error(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Field cultivation not found: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Record invalid: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::FieldCultivation::Errors::NoWeatherLocationError,
               Domain::FieldCultivation::Errors::NoCultivationPeriodError,
               Domain::FieldCultivation::Errors::WeatherPayloadInvalidError => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Climate precondition: #{e.class}: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        end

        private

        def assert_climate_preconditions!(source)
          if Policies::FieldCultivationClimatePreconditionsPolicy.missing_weather_location?(
            weather_location_id: source.weather_location_id
          )
            raise Domain::FieldCultivation::Errors::NoWeatherLocationError,
                  @translator.t("api.errors.no_weather_data")
          end

          if Policies::FieldCultivationClimatePreconditionsPolicy.missing_cultivation_period?(
            start_date: source.start_date,
            completion_date: source.completion_date
          )
            raise Domain::FieldCultivation::Errors::NoCultivationPeriodError,
                  @translator.t("api.errors.no_cultivation_period")
          end
        end

        def resolve_crop_entity(source:, user_dto:)
          crop_id = source.plan_crop_crop_id
          return nil if crop_id.blank?

          crop_entity = @crop_gateway.find_by_id(crop_id.to_i)
          unless Policies::FieldCultivationClimateCropViewPolicy.view_allowed?(
            user: user_dto,
            crop_entity: crop_entity,
            plan_type_public: source.plan_type_public
          )
            return nil
          end

          crop_entity
        rescue Domain::Shared::Exceptions::RecordNotFound
          nil
        end

        def crop_not_found_message
          @translator.t("api.errors.crop_not_found")
        end

        def assemble_climate_data(source:, context:, crop_entity:, display_start_date:, display_end_date:)
          weather_payload = fetch_primary_weather_payload(
            source: source,
            context: context,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
          return assemble_climate_data_from_fallback(
            source: source,
            context: context,
            crop_entity: crop_entity,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          ) if weather_payload.nil?

          build_climate_output(context, crop_entity, weather_payload)
        end

        def assemble_climate_data_from_fallback(source:, context:, crop_entity:, display_start_date:, display_end_date:)
          weather_payload = fetch_fallback_weather_payload(
            source: source,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
          return nil if weather_payload.nil?

          persist_predicted_weather_if_absent!(source, weather_payload)
          build_climate_output(context, crop_entity, weather_payload)
        end

        def build_climate_output(context, crop_entity, weather_payload)
          weather_records = Mappers::FieldCultivationClimateDataMapper.extract_weather_records(
            weather_payload,
            context.start_date,
            context.completion_date
          )
          crop_record = @crop_gateway.find_crop_record_with_stages!(crop_entity.id)
          crop_requirement = @crop_agrr_requirement_builder.build_from(crop_record)
          progress_result = @climate_progress_gateway.calculate_progress(
            crop_requirement: crop_requirement,
            start_date: context.start_date,
            weather_payload: weather_payload,
            crop: crop_record
          )

          Mappers::FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )
        end

        def fetch_primary_weather_payload(source:, context:, display_start_date:, display_end_date:)
          weather_payload = if context.plan_predicted_weather_present
            merge_cached_prediction_with_observed(
              source: source,
              context: context,
              display_start_date: display_start_date,
              display_end_date: display_end_date
            )
          else
            @logger.warn "⚠️ [FieldCultivationClimateDataInteractor] No cached prediction for CultivationPlan##{context.plan_id}, generating"
            invoke_plan_prediction(source: source)
          end

          return nil if weather_payload.nil?

          assert_valid_weather_payload!(context.plan_id, weather_payload)
          weather_payload
        end

        def invoke_plan_prediction(source:)
          targets = @climate_source_gateway.find_weather_prediction_targets_by_plan_id(source.plan_id)
          plan_weather = Mappers::FieldCultivationClimatePlanWeatherMapper.to_cultivation_plan_weather(source: source)
          service = @weather_prediction_gateway.prediction_service(
            weather_location: targets.weather_location,
            farm: targets.farm
          )
          prediction_info = service.predict_for_cultivation_plan(plan_weather: plan_weather)
          return nil unless prediction_info.is_a?(Hash)

          prediction_info[:data]
        end

        def merge_cached_prediction_with_observed(source:, context:, display_start_date:, display_end_date:)
          @logger.info "✅ [FieldCultivationClimateDataInteractor] Using saved prediction for CultivationPlan##{context.plan_id}, merging with observed data"
          cached = context.predicted_weather_data

          decision = Policies::FieldCultivationClimateObservedMergeRangePolicy.resolve(
            display_start_date: display_start_date,
            display_end_date: display_end_date,
            cultivation_start_date: context.start_date,
            cultivation_end_date: context.completion_date,
            today: @clock.today
          )
          return cached if decision.skip?

          observed_dtos = @weather_data_gateway.weather_data_for_period(
            weather_location_id: source.weather_location_id,
            start_date: decision.start_date,
            end_date: decision.end_date
          )
          return cached if observed_dtos.empty?

          observed_formatted = Mappers::FieldCultivationClimateWeatherPayloadMapper.build_observed_agrr_payload(
            weather_location_meta: Mappers::FieldCultivationClimateWeatherPayloadMapper.weather_location_meta_from_source(source: source),
            observed_weather_dtos: observed_dtos
          )

          Mappers::FieldCultivationClimateWeatherPayloadMapper.merge_cached_with_observed(
            cached_weather_payload: cached,
            observed_formatted: observed_formatted
          )
        end

        def fetch_fallback_weather_payload(source:, display_start_date:, display_end_date:)
          @logger.info "Fallback to on-the-fly prediction for field_cultivation_id=#{source.field_cultivation_id}"
          anchors = @anchors_resolver.anchors_for(@clock.today)
          training_start_date = anchors.training_start_date
          training_end_date = anchors.training_end_date
          prediction_targets = @climate_source_gateway.find_weather_prediction_targets_by_plan_id(source.plan_id)
          weather_location = prediction_targets.weather_location
          weather_location_meta = Mappers::FieldCultivationClimateWeatherPayloadMapper.weather_location_meta_from_source(source: source)

          training_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: source.weather_location_id,
            start_date: training_start_date,
            end_date: training_end_date
          )

          training_formatted = Mappers::FieldCultivationClimateWeatherPayloadMapper.build_observed_agrr_payload_simple(
            weather_location_meta: weather_location_meta,
            observed_weather_dtos: training_data
          )

          prediction_days = Policies::FieldCultivationClimateFallbackHorizonPolicy.prediction_days(
            completion_date: source.completion_date,
            training_end_date: training_end_date
          )

          if Policies::FieldCultivationClimateFallbackHorizonPolicy.use_prediction_branch?(prediction_days: prediction_days)
            future = @prediction_gateway.predict(
              historical_data: training_formatted,
              days: prediction_days,
              model: "lightgbm"
            )
            return nil unless future.is_a?(Hash)

            decision = Policies::FieldCultivationClimateObservedMergeRangePolicy.resolve(
              display_start_date: display_start_date,
              display_end_date: display_end_date,
              cultivation_start_date: source.start_date,
              cultivation_end_date: source.completion_date,
              today: @clock.today
            )

            if decision.skip?
              observed_start = Date.new(@clock.today.year, 1, 1)
              observed_end = training_end_date
            else
              observed_start = decision.start_date
              observed_end = decision.end_date
            end

            current_year_data = @weather_data_gateway.weather_data_for_period(
              weather_location_id: source.weather_location_id,
              start_date: observed_start,
              end_date: observed_end
            )

            current_year_formatted = Mappers::FieldCultivationClimateWeatherPayloadMapper.build_observed_agrr_payload_simple(
              weather_location_meta: weather_location_meta,
              observed_weather_dtos: current_year_data
            )

            Mappers::FieldCultivationClimateWeatherPayloadMapper.merge_training_and_future(
              training_formatted: current_year_formatted,
              future_payload: future
            )
          else
            @weather_data_gateway.format_for_agrr(
              weather_data_dtos: @weather_data_gateway.weather_data_for_period(
                weather_location_id: source.weather_location_id,
                start_date: source.start_date,
                end_date: source.completion_date
              ),
              weather_location: weather_location
            )
          end
        end

        def persist_predicted_weather_if_absent!(source, weather_payload)
          return if Domain::Shared::ValidationHelpers.present?(source.predicted_weather_data)

          @cultivation_plan_gateway.update_predicted_weather_data(source.plan_id, weather_payload)
          @logger.info "💾 [FieldCultivationClimateDataInteractor] Saved prediction data to CultivationPlan##{source.plan_id}"
        end

        def assert_valid_weather_payload!(plan_id, weather_payload)
          return if Mappers::FieldCultivationClimateWeatherPayloadMapper.valid_weather_payload?(weather_payload)

          @logger.error "❌ [FieldCultivationClimateDataInteractor] Invalid weather payload for CultivationPlan##{plan_id}"
          raise Domain::FieldCultivation::Errors::WeatherPayloadInvalidError,
                @translator.t("controllers.field_cultivations.errors.weather_format_invalid")
        end

        def apply_display_range(climate_data, display_start_date, display_end_date)
          return climate_data unless display_start_date || display_end_date

          gantt_start = parse_date(display_start_date)
          gantt_end = parse_date(display_end_date)
          return climate_data unless gantt_start && gantt_end

          cultivation_start = parse_date(climate_data.field_cultivation[:start_date] || climate_data.field_cultivation["start_date"])
          cultivation_end = parse_date(climate_data.field_cultivation[:completion_date] || climate_data.field_cultivation["completion_date"])

          effective_start = [
            cultivation_start,
            gantt_start
          ].compact.max

          effective_end = [
            cultivation_end,
            gantt_end
          ].compact.min

          if effective_start > effective_end
            effective_start = gantt_start
            effective_end = gantt_end
          end

          filtered_weather = filter_weather_data(climate_data.weather_data, effective_start, effective_end)
          filtered_gdd = filter_gdd_data(climate_data.gdd_data, effective_start, effective_end)

          adjusted_field_cultivation = climate_data.field_cultivation.merge(
            start_date: effective_start.to_s,
            completion_date: effective_end.to_s
          )

          debug_info = (climate_data.debug_info || {}).merge(
            display_range: {
              gantt_start: gantt_start.to_s,
              gantt_end: gantt_end.to_s,
              cultivation_start: cultivation_start&.to_s,
              cultivation_end: cultivation_end&.to_s,
              effective_start: effective_start.to_s,
              effective_end: effective_end.to_s,
              weather_records: filtered_weather.length,
              gdd_records: filtered_gdd.length,
              note: "All components use intersection of cultivation period and gantt chart bounds"
            }
          )

          Domain::FieldCultivation::Dtos::FieldCultivationClimateDataOutput.new(
            field_cultivation: adjusted_field_cultivation,
            farm: climate_data.farm,
            crop_requirements: climate_data.crop_requirements,
            weather_data: filtered_weather,
            gdd_data: filtered_gdd,
            stages: climate_data.stages,
            progress_result: climate_data.progress_result,
            debug_info: debug_info
          )
        end

        def filter_weather_data(weather_data, range_start, range_end)
          Domain::Shared.to_array(weather_data).select do |datum|
            date_value = parse_date(datum["date"] || datum[:date])
            next false unless date_value

            date_value >= range_start && date_value <= range_end
          end
        end

        def filter_gdd_data(gdd_data, range_start, range_end)
          Domain::Shared.to_array(gdd_data).select do |datum|
            date_value = parse_date(datum["date"] || datum[:date])
            next false unless date_value

            date_value >= range_start && date_value <= range_end
          end
        end

        def parse_date(value)
          return nil unless value

          Date.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
