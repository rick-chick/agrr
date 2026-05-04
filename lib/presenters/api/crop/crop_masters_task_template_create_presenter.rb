# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropMastersTaskTemplateCreatePresenter < Domain::Crop::Ports::CropMastersTaskTemplateCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(template_dto)
          @view.render_response(json: build_template_json(template_dto), status: :created)
        end

        def on_failure(failure_dto)
          case failure_dto.reason
          when :missing_agricultural_task_id
            render_error("agricultural_task_id is required", :unprocessable_entity)
          when :agricultural_task_not_found
            render_error("AgriculturalTask not found", :not_found)
          when :forbidden
            render_error("You do not have permission to associate this agricultural task", :forbidden)
          when :duplicate
            render_error("AgriculturalTask is already associated with this crop", :unprocessable_entity)
          when :validation_failed
            @view.render_response(json: { errors: failure_dto.errors || [] }, status: :unprocessable_entity)
          when :crop_not_found
            render_error("Crop not found", :not_found)
          else
            render_error(failure_dto.message.to_s, :unprocessable_entity)
          end
        end

        private

        def render_error(message, status)
          @view.render_response(json: { error: message }, status: status)
        end

        def build_template_json(template)
          task = template.agricultural_task
          {
            id: template.id,
            crop_id: template.crop_id,
            agricultural_task_id: template.agricultural_task_id,
            name: template.name,
            description: template.description,
            time_per_sqm: template.time_per_sqm,
            weather_dependency: template.weather_dependency,
            required_tools: template.required_tools || [],
            skill_level: template.skill_level,
            agricultural_task: task ? {
              id: task.id,
              name: task.name,
              description: task.description,
              is_reference: task.is_reference
            } : nil,
            created_at: template.created_at,
            updated_at: template.updated_at
          }
        end
      end
    end
  end
end
