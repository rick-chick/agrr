# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAddCropBestCandidateActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAddCropBestCandidateGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def find_best(auth:, plan_id:, crop_id:, field_id:, display_range:, optimization_host:)
          ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          crop = ::Crop.find(crop_id)

          best_candidate =
            optimization_host.find_best_candidate_for_crop(crop, field_id, display_range: display_range)

          unless best_candidate
            return { kind: :no_candidates }
          end

          {
            kind: :found,
            field_id: best_candidate[:field_id] || field_id,
            start_date: best_candidate[:start_date]
          }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
               Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
          logger.warn "⚠️ [Add Crop candidate] Prediction data incomplete: #{e.message}"
          { kind: :prediction_incomplete, technical_details: e.message }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Add Crop candidate] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Add Crop candidate] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
