# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskUpdateHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateOutputPort
        def initialize(view:, form_resubmit: nil)
          @view = view
          @form_resubmit = form_resubmit
        end

        def on_success(task)
          @view.redirect_to @view.agricultural_task_path(task), notice: I18n.t("agricultural_tasks.flash.updated")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("agricultural_tasks.flash.no_permission")
            @view.redirect_to @view.agricultural_tasks_path
            return
          end

          @view.apply_agricultural_task_update_form_snapshot(@form_resubmit) if @form_resubmit
          @view.flash.now[:alert] = error_dto.message
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
