# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class CropMastersTaskTemplateCreatePresenter < Domain::Crop::Ports::CropMastersTaskTemplateCreateOutputPort
          ERRORS_SCOPE = %i[controllers api masters crops agricultural_tasks errors].freeze

          def initialize(view:, translator:)
            @view = view
            @translator = translator
          end

          def on_success(template_dto)
            @view.render_response(json: build_template_json(template_dto), status: :created)
          end

          def on_failure(failure_dto)
            case failure_dto.reason
            when :missing_agricultural_task_id
              render_error(t_error(:missing_agricultural_task_id), :unprocessable_entity)
            when :agricultural_task_not_found
              render_error(t_error(:agricultural_task_not_found), :not_found)
            when :forbidden
              render_error(t_error(:forbidden_associate), :forbidden)
            when :duplicate
              render_error(t_error(:duplicate_associate), :unprocessable_entity)
            when :validation_failed
              @view.render_response(json: { errors: failure_dto.errors || [] }, status: :unprocessable_entity)
            when :crop_not_found
              render_error(t_error(:crop_not_found), :not_found)
            else
              if development_environment?
                raise ArgumentError,
                      "CropMastersTaskTemplateCreatePresenter: unknown failure reason #{failure_dto.reason.inspect}"
              end

              msg = failure_dto.message.presence || t_error(:unexpected)
              render_error(msg, :unprocessable_entity)
            end
          end

          private

          def development_environment?
            defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
          end

          def t_error(key)
            @translator.t(key, scope: ERRORS_SCOPE, default: FALLBACK.fetch(key))
          end

          FALLBACK = {
            missing_agricultural_task_id: "agricultural_task_id is required",
            agricultural_task_not_found: "AgriculturalTask not found",
            forbidden_associate: "You do not have permission to associate this agricultural task",
            duplicate_associate: "AgriculturalTask is already associated with this crop",
            crop_not_found: "Crop not found",
            unexpected: "Request could not be processed"
          }.freeze

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
end
