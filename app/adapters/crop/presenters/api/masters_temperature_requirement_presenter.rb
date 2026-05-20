# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class MastersTemperatureRequirementPresenter < Domain::Crop::Ports::MastersTemperatureRequirementOutputPort
          def initialize(view:)
            @view = view
          end

          def on_show_success(requirement_entity)
            @view.render_response(json: serialize(requirement_entity), status: :ok)
          end

          def on_create_success(requirement_entity)
            @view.render_response(json: serialize(requirement_entity), status: :created)
          end

          def on_update_success(requirement_entity)
            @view.render_response(json: serialize(requirement_entity), status: :ok)
          end

          def on_not_found
            @view.render_response(json: { error: "TemperatureRequirement not found" }, status: :not_found)
          end

          def on_already_exists
            @view.render_response(json: { error: "TemperatureRequirement already exists" }, status: :unprocessable_entity)
          end

          def on_validation_errors(error_messages)
            @view.render_response(json: { errors: error_messages }, status: :unprocessable_entity)
          end

          def on_destroy_success
            @view.render_no_content
          end

          private

          def serialize(requirement)
            {
              id: requirement.id,
              crop_stage_id: requirement.crop_stage_id,
              base_temperature: requirement.base_temperature,
              optimal_min: requirement.optimal_min,
              optimal_max: requirement.optimal_max,
              low_stress_threshold: requirement.low_stress_threshold,
              high_stress_threshold: requirement.high_stress_threshold,
              frost_threshold: requirement.frost_threshold,
              sterility_risk_threshold: requirement.sterility_risk_threshold,
              max_temperature: requirement.max_temperature
            }
          end
        end
      end
    end
  end
end
