# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class MastersSunshineRequirementPresenter < Domain::Crop::Ports::MastersSunshineRequirementOutputPort
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
          @view.render_response(json: { error: "SunshineRequirement not found" }, status: :not_found)
        end

        def on_already_exists
          @view.render_response(json: { error: "SunshineRequirement already exists" }, status: :unprocessable_entity)
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
            minimum_sunshine_hours: requirement.minimum_sunshine_hours,
            target_sunshine_hours: requirement.target_sunshine_hours
          }
        end
      end
    end
  end
end
