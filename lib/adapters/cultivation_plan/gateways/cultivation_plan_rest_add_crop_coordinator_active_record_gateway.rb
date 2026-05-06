# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestAddCropCoordinatorActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanRestAddCropCoordinatorGateway
        def initialize(optimization_host:, logger:)
          super(logger: logger)
          @optimization_host = optimization_host
        end

        def run(auth:, plan_id:, crop_id:, field_id:, display_range:, crop_resolver:)
          optimization_host = @optimization_host

          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan_id)

          optimization_host.attach_plan_for_candidates(cultivation_plan)

          crop_entity = crop_resolver.crop_for_add_crop(crop_id)
          unless crop_entity
            return { kind: :crop_not_found }
          end

          crop = ::Crop.find(crop_entity.id)

          plan_crop = cultivation_plan.cultivation_plan_crops.create!(
            crop: crop,
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area
          )

          best_candidate =
            begin
              optimization_host.find_best_candidate_for_crop(crop, field_id, display_range: display_range)
            rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
                   Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
              plan_crop.destroy! if plan_crop.persisted?
              logger.warn "⚠️ [Add Crop] Prediction data incomplete: #{e.message}"
              return { kind: :prediction_incomplete, technical_details: e.message }
            end

          unless best_candidate
            plan_crop.destroy!
            return { kind: :no_candidates }
          end

          logger.info "🌱 [Add Crop] Best candidate: field=#{best_candidate[:field_id]}, start=#{best_candidate[:start_date]}"

          moves = [
            {
              allocation_id: nil,
              action: "add",
              crop_id: crop.id.to_s,
              to_field_id: best_candidate[:field_id] || field_id,
              to_start_date: best_candidate[:start_date],
              to_area: crop.area_per_unit,
              variety: crop.variety
            }
          ]

          result = optimization_host.adjust_with_db_weather(cultivation_plan, moves)

          if result[:success]
            {
              kind: :success,
              plan_crop_id: plan_crop.id,
              plan_crop_display_name: plan_crop.display_name
            }
          else
            { kind: :adjust_failed, adjust_payload: result }
          end
        rescue ActiveRecord::RecordNotFound => e
          logger.error "❌ [Add Crop] Not found: #{e.message}"
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Add Crop] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          logger.error "❌ [Add Crop] Domain record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue StandardError => e
          logger.error "❌ [Add Crop] Error: #{e.message}"
          logger.error e.backtrace.join("\n")
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
