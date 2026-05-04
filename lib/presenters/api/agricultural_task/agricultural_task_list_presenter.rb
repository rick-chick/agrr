# frozen_string_literal: true

module Presenters
  module Api
    module AgriculturalTask
      class AgriculturalTaskListPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(tasks, reference_tasks_for_index: [])
          json = tasks.is_a?(Array) ? tasks.map { |e| entity_to_json(e) } : []
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.render_response(
              json: { error: I18n.t("agricultural_tasks.flash.no_permission") },
              status: :forbidden
            )
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render_response(json: { error: msg }, status: :unprocessable_entity)
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            user_id: entity.user_id,
            name: entity.name,
            description: entity.description,
            time_per_sqm: entity.time_per_sqm,
            weather_dependency: entity.weather_dependency,
            required_tools: entity.required_tools,
            skill_level: entity.skill_level,
            region: entity.region,
            task_type: entity.task_type,
            is_reference: entity.is_reference,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
