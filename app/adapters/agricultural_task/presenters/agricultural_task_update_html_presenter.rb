# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskUpdateHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(task)
          @view.redirect_to @view.agricultural_task_path(task), notice: I18n.t("agricultural_tasks.flash.updated")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.agricultural_tasks_path,
                               alert: I18n.t("agricultural_tasks.flash.no_permission")
            return
          end

          if error_dto.is_a?(Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure)
            @view.redirect_to @view.agricultural_task_path(error_dto.resource_id), alert: error_dto.message
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          task_id = @view.params[:id]
          path = task_id.present? ? @view.agricultural_task_path(task_id) : @view.agricultural_tasks_path
          @view.redirect_to path, alert: msg
        end
      end
    end
  end
end
