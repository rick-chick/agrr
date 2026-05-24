# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateSourceGateway
        def find_plan_access_context(field_cultivation_id)
          raise NotImplementedError
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_by_field_cultivation_id(field_cultivation_id)
          raise NotImplementedError
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationWeatherPredictionTargets]
        def find_weather_prediction_targets_by_plan_id(plan_id)
          raise NotImplementedError
        end

        def find_api_summary(field_cultivation_id:)
          raise NotImplementedError
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil)
          raise NotImplementedError
        end
      end
    end
  end
end
