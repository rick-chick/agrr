# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskListHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskListOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:, input_dto: nil)
          @view = view
          @input_dto = input_dto || Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.new(is_admin: false)
        end

        def on_success(rows, page_display: nil, reference_tasks_for_index: [])
          assign_list_row_view_models(@view, :@agricultural_tasks, rows)
          assign_html_display(@view, page_display) if page_display
          @view.instance_variable_set(:@query, @input_dto.query.to_s)
          @view.instance_variable_set(:@selected_filter, @input_dto.filter.to_s)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.agricultural_tasks_path,
                               alert: I18n.t("agricultural_tasks.flash.no_permission")
            return
          end

          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@agricultural_tasks, [])
        end
      end
    end
  end
end
