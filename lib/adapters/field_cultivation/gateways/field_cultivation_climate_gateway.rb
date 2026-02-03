# frozen_string_literal: true

require_dependency 'field_cultivation_climate/mock_progress_records'

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateGateway < Domain::FieldCultivation::Gateways::FieldCultivationGateway
        include ::FieldCultivationClimate::MockProgressRecords
        def initialize(current_user:, use_mock_progress: nil,
                       progress_gateway_factory: nil,
                       weather_prediction_service_factory: nil)
          @current_user = current_user
          @use_mock_progress = use_mock_progress.nil? ? Rails.env.test? : use_mock_progress
          @progress_gateway_factory = progress_gateway_factory || -> { Agrr::ProgressGateway.new }
          @weather_prediction_service_factory = weather_prediction_service_factory ||
            ->(weather_location, farm) { WeatherPredictionService.new(weather_location: weather_location, farm: farm) }
        end

        def fetch_field_cultivation_climate_data(field_cultivation_id:)
          field_cultivation = find_authorized_field_cultivation(field_cultivation_id)
          plan = field_cultivation.cultivation_plan
          farm = plan.farm

          ensure_weather_location!(farm)
          ensure_cultivation_period!(field_cultivation)

          crop = fetch_crop(field_cultivation, plan_type_public: plan.plan_type_public?)
          raise ActiveRecord::RecordNotFound, I18n.t('api.errors.crop_not_found') unless crop

          weather_payload = fetch_weather_payload(plan, farm)
          ensure_weather_payload!(plan, weather_payload)

          weather_data_records = extract_actual_weather_data(
            weather_payload,
            field_cultivation.start_date,
            field_cultivation.completion_date
          )

          progress_result = build_progress_result(crop, field_cultivation, weather_payload)
          temp_req = crop.crop_stages.order(:order).first&.temperature_requirement

          daily_gdd, baseline_gdd, filtered_records, progress_records = build_daily_gdd(
            progress_result,
            weather_data_records,
            field_cultivation,
            temp_req&.base_temperature || 10.0
          )

          build_success_dto(
            field_cultivation: field_cultivation,
            farm: farm,
            weather_data_records: weather_data_records,
            temp_req: temp_req,
            optimal_temperature_range: build_optimal_temperature_range(temp_req),
            daily_gdd: daily_gdd,
            progress_result: progress_result,
            stages: build_stage_requirements(crop),
            baseline_gdd: baseline_gdd,
            filtered_records: filtered_records,
            progress_records: progress_records
          )
        rescue PolicyPermissionDenied
          raise ActiveRecord::RecordNotFound
        end

        private

        def build_success_dto(field_cultivation:, farm:, weather_data_records:, temp_req:,
                              optimal_temperature_range:, daily_gdd:, progress_result:, stages:,
                              baseline_gdd:, filtered_records:, progress_records:)
          Domain::FieldCultivation::Dtos::FieldCultivationClimateDataSuccessDto.new(
            field_cultivation: {
              id: field_cultivation.id,
              field_name: field_cultivation.field_display_name,
              crop_name: field_cultivation.crop_display_name,
              start_date: field_cultivation.start_date,
              completion_date: field_cultivation.completion_date
            },
            farm: {
              id: farm.id,
              name: farm.display_name,
              latitude: farm.latitude,
              longitude: farm.longitude
            },
            crop_requirements: {
              base_temperature: temp_req&.base_temperature || 10.0,
              optimal_temperature_range: optimal_temperature_range
            },
            weather_data: weather_data_records.map do |datum|
              {
                date: datum[:date],
                temperature_max: datum[:temperature_max],
                temperature_min: datum[:temperature_min],
                temperature_mean: datum[:temperature_mean]
              }
            end,
            gdd_data: daily_gdd,
            stages: stages,
            progress_result: progress_result,
            debug_info: {
              baseline_gdd: baseline_gdd,
              progress_records_count: progress_records.length,
              filtered_records_count: filtered_records.length,
              using_agrr_progress: progress_records.any?,
              sample_raw_data: progress_records.first(3)
            }
          )
        end

        def find_authorized_field_cultivation(field_cultivation_id)
          field_cultivation = ::FieldCultivation.find(field_cultivation_id)
          plan = field_cultivation.cultivation_plan
          if plan.plan_type_public?
            PlanPolicy.find_public!(plan.id)
          else
            PlanPolicy.find_private_owned!(@current_user, plan.id)
          end
          field_cultivation
        end

        def ensure_weather_location!(farm)
          return if farm&.weather_location

          raise StandardError, I18n.t('api.errors.no_weather_data')
        end

        def ensure_cultivation_period!(field_cultivation)
          return if field_cultivation.start_date && field_cultivation.completion_date

          raise StandardError, I18n.t('api.errors.no_cultivation_period')
        end

        def fetch_crop(field_cultivation, plan_type_public:)
          plan_crop = field_cultivation.cultivation_plan_crop
          Rails.logger.debug("[FieldCultivationClimateGateway] plan_crop.crop_id=#{plan_crop&.crop_id}, plan_type_public=#{plan_type_public}, current_user_id=#{@current_user&.id}")
          if plan_type_public
            ::Crop.find_by(id: plan_crop.crop_id)
          else
            Domain::Shared::Policies::CropPolicy
              .user_owned_non_reference_scope(::Crop, @current_user)
              .find_by(id: plan_crop.crop_id)
          end
        end

        def fetch_weather_payload(plan, farm)
          if plan.predicted_weather_data.present?
            Rails.logger.info "✅ [FieldCultivationClimateGateway] Using saved prediction for CultivationPlan##{plan.id}"
            AgrrService.normalize_weather_data(plan.predicted_weather_data)
          else
            Rails.logger.warn "⚠️ [FieldCultivationClimateGateway] No cached prediction for CultivationPlan##{plan.id}, generating"
            service = @weather_prediction_service_factory.call(farm.weather_location, farm)
            prediction_info = service.predict_for_cultivation_plan(plan)
            prediction_info[:data]
          end
        end

        def ensure_weather_payload!(plan, weather_payload)
          return if weather_payload && weather_payload['data']

          Rails.logger.error "❌ [FieldCultivationClimateGateway] Invalid weather payload for CultivationPlan##{plan.id}"
          raise StandardError, I18n.t('controllers.field_cultivations.errors.weather_format_invalid')
        end

        def build_progress_result(crop, field_cultivation, weather_payload)
          return mock_progress_result(field_cultivation) if @use_mock_progress

          progress_gateway = @progress_gateway_factory.call
          progress_gateway.calculate_progress(
            crop: crop,
            start_date: field_cultivation.start_date,
            weather_data: weather_payload
          )
        end

        def mock_progress_result(field_cultivation)
          Rails.logger.info "🧪 [FieldCultivationClimateGateway] Using mock progress for field_cultivation_id=#{field_cultivation.id}"
          {
            'progress_records' => generate_mock_progress_records(
              field_cultivation.start_date,
              field_cultivation.completion_date
            ),
            'total_gdd' => 875.0
          }
        end

        def build_optimal_temperature_range(temp_req)
          return nil unless temp_req

          {
            min: temp_req.optimal_min,
            max: temp_req.optimal_max,
            low_stress: temp_req.low_stress_threshold,
            high_stress: temp_req.high_stress_threshold
          }
        end

        def build_daily_gdd(progress_result, weather_data_records, field_cultivation, base_temp)
          progress_records = progress_result['progress_records'] || []
          baseline_gdd = 0.0
          filtered_records = []
          daily_gdd = []

          if progress_records.empty?
            daily_gdd = calculate_gdd_manually(weather_data_records, base_temp)
          else
            filtered_records = progress_records.select do |record|
              record_date = Date.parse(record['date']) rescue nil
              next false unless record_date
              (field_cultivation.start_date..field_cultivation.completion_date).cover?(record_date)
            end

            start_index = progress_records.index do |record|
              Date.parse(record['date']) == field_cultivation.start_date rescue false
            end
            baseline_gdd = start_index && start_index.positive? ? (progress_records[start_index - 1]['cumulative_gdd'] || 0.0) : 0.0

            filtered_records.each_with_index do |day, index|
              current_cumulative_raw = day['cumulative_gdd'] || 0.0
              current_cumulative = current_cumulative_raw - baseline_gdd
              prev_cumulative = index.positive? ? (filtered_records[index - 1]['cumulative_gdd'] - baseline_gdd) : 0.0
              daily_gdd_value = current_cumulative - prev_cumulative

              daily_gdd << {
                date: day['date'],
                gdd: daily_gdd_value.round(2),
                cumulative_gdd: current_cumulative.round(2),
                temperature: nil,
                current_stage: day['stage_name']
              }
            end
          end

          [daily_gdd, baseline_gdd, filtered_records, progress_records]
        end

        def calculate_gdd_manually(weather_data_records, base_temp)
          daily_gdd = []
          cumulative_gdd = 0.0

          weather_data_records.each do |datum|
            avg_temp = if datum[:temperature_mean]
              datum[:temperature_mean]
            elsif datum[:temperature_max] && datum[:temperature_min]
              (datum[:temperature_max] + datum[:temperature_min]) / 2.0
            end
            next unless avg_temp

            gdd_value = [avg_temp - base_temp, 0].max
            cumulative_gdd += gdd_value

            daily_gdd << {
              date: datum[:date],
              gdd: gdd_value.round(2),
              cumulative_gdd: cumulative_gdd.round(2),
              temperature: avg_temp.round(2),
              current_stage: nil
            }
          end

          daily_gdd
        end

        def build_stage_requirements(crop)
          return [] unless crop&.crop_stages&.any?

          cumulative_gdd = 0.0

          crop.crop_stages.order(:order).filter_map do |crop_stage|
            temp_req = crop_stage.temperature_requirement
            thermal_req = crop_stage.thermal_requirement
            next unless temp_req && thermal_req

            cumulative_gdd += thermal_req.required_gdd

            {
              name: crop_stage.name,
              order: crop_stage.order,
              gdd_required: thermal_req.required_gdd,
              cumulative_gdd_required: cumulative_gdd.round(2),
              optimal_temperature_min: temp_req.optimal_min,
              optimal_temperature_max: temp_req.optimal_max,
              low_stress_threshold: temp_req.low_stress_threshold,
              high_stress_threshold: temp_req.high_stress_threshold
            }
          end
        end

        def extract_actual_weather_data(weather_payload, start_date, end_date)
          return [] unless weather_payload && weather_payload['data']

          weather_payload['data'].filter_map do |datum|
            next unless datum && datum['time']
            datum_date = Date.parse(datum['time']) rescue nil
            next unless datum_date
            next unless datum_date.between?(start_date, end_date)

            temp_mean = datum['temperature_2m_mean']
            if temp_mean.nil? && datum['temperature_2m_max'] && datum['temperature_2m_min']
              temp_mean = (datum['temperature_2m_max'] + datum['temperature_2m_min']) / 2.0
            end

            {
              date: datum['time'],
              temperature_max: datum['temperature_2m_max'],
              temperature_min: datum['temperature_2m_min'],
              temperature_mean: temp_mean
            }
          end
        end
      end
    end
  end
end
