# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskDetailHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(detail_dto)
          @view.instance_variable_set(:@agricultural_task, detail_dto)
          assign_html_display(@view, detail_dto.html_display) if detail_dto.html_display
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("agricultural_tasks.flash.no_permission")
            @view.redirect_to @view.agricultural_tasks_path
            return
          end

          @view.flash[:alert] = error_dto.message
          @view.redirect_to @view.agricultural_tasks_path
        end
      end
    end
  end
end
