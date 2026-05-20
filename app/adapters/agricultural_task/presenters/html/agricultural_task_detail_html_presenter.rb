# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      module Html
        class AgriculturalTaskDetailHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(detail_dto)
            @view.instance_variable_set(:@agricultural_task, detail_dto)
          end

          def on_failure(error_dto)
            if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.flash[:alert] = I18n.t("agricultural_tasks.flash.no_permission")
              @view.redirect_to @view.agricultural_tasks_path
              return
            end

            @view.flash.now[:alert] = error_dto.message
            @view.redirect_to @view.agricultural_tasks_path
          end
        end
      end
    end
  end
end
