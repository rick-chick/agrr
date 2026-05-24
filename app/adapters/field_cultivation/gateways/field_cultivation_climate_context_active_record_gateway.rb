# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateContextActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateContextGateway
        def initialize(current_user:, logger:, translator:)
          @current_user = current_user
          @logger = logger
          @translator = translator
        end

        def find_plan_access_context(field_cultivation_id)
          fc = find_field_cultivation_model!(field_cultivation_id)
          plan = fc.cultivation_plan
          Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessContext.new(
            field_cultivation_id: fc.id,
            plan_type_public: plan.plan_type_public?,
            plan_type_private: plan.plan_type_private?,
            plan_user_id: plan.user_id
          )
        end

        def load_context(field_cultivation_id:)
          field_cultivation = find_field_cultivation_model!(field_cultivation_id)
          plan = field_cultivation.cultivation_plan
          farm = plan.farm

          ensure_weather_location!(farm)
          ensure_cultivation_period!(field_cultivation)

          crop = fetch_crop(field_cultivation, plan_type_public: plan.plan_type_public?)
          raise Domain::Shared::Exceptions::RecordNotFound, @translator.t("api.errors.crop_not_found") unless crop

          temp_req = crop.crop_stages.order(:order).first&.temperature_requirement

          Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot.new(
            field_cultivation_id: field_cultivation.id,
            field_name: field_cultivation.field_display_name,
            crop_name: field_cultivation.crop_display_name,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            farm_id: farm.id,
            farm_name: farm.display_name,
            farm_latitude: farm.latitude,
            farm_longitude: farm.longitude,
            plan_id: plan.id,
            plan_type_public: plan.plan_type_public?,
            plan_predicted_weather_present: Domain::Shared::ValidationHelpers.present?(plan.predicted_weather_data),
            prediction_target_end_date: plan.prediction_target_end_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            crop_id: crop.id,
            base_temperature: temp_req&.base_temperature || 10.0,
            optimal_temperature_range: build_optimal_temperature_range(temp_req),
            stages: build_stage_requirements(crop)
          )
        end

        def find_api_summary(field_cultivation_id:)
          fc = find_field_cultivation_model!(field_cultivation_id)
          Domain::FieldCultivation::Dtos::FieldCultivationApiSummary.new(
            id: fc.id,
            field_name: fc.field_display_name,
            crop_name: fc.crop_display_name,
            area: fc.area,
            start_date: fc.start_date,
            completion_date: fc.completion_date,
            cultivation_days: fc.cultivation_days,
            estimated_cost: fc.estimated_cost,
            gdd: fc.optimization_result&.dig("raw", "total_gdd"),
            status: fc.status
          )
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, public_plan: false)
          fc = find_field_cultivation_model!(field_cultivation_id)
          unless fc.update(start_date: start_date, completion_date: completion_date)
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: fc.errors.full_messages)
          end

          cultivation_days_value = fc.cultivation_days
          if public_plan && fc.start_date && fc.completion_date
            days = (fc.completion_date - fc.start_date).to_i + 1
            fc.update_column(:cultivation_days, days)
            cultivation_days_value = days
          end

          if public_plan
            Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput.new(
              field_cultivation_id: fc.id,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: cultivation_days_value,
              message: "栽培期間を更新しました"
            )
          else
            Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput.new(
              field_cultivation_id: fc.id,
              start_date: fc.start_date,
              completion_date: fc.completion_date
            )
          end
        end

        private

        def find_field_cultivation_model!(field_cultivation_id)
          ::FieldCultivation.find(field_cultivation_id)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def ensure_weather_location!(farm)
          return if farm&.weather_location

          raise Domain::FieldCultivation::Errors::NoWeatherLocationError, @translator.t("api.errors.no_weather_data")
        end

        def ensure_cultivation_period!(field_cultivation)
          return if field_cultivation.start_date && field_cultivation.completion_date

          raise Domain::FieldCultivation::Errors::NoCultivationPeriodError, @translator.t("api.errors.no_cultivation_period")
        end

        def fetch_crop(field_cultivation, plan_type_public:)
          plan_crop = field_cultivation.cultivation_plan_crop
          @logger.debug(
            "[FieldCultivationClimateContextActiveRecordGateway] plan_crop.crop_id=#{plan_crop&.crop_id}, " \
            "plan_type_public=#{plan_type_public}, current_user_id=#{@current_user&.id}"
          )
          if plan_type_public
            ::Crop.find_by(id: plan_crop.crop_id)
          else
            return nil unless @current_user

            ::Crop.where(user_id: @current_user.id, is_reference: false).find_by(id: plan_crop.crop_id)
          end
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
      end
    end
  end
end
