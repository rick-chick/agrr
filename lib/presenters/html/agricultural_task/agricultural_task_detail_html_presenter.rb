# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskDetailHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(detail_dto)
          @view.instance_variable_set(:@agricultural_task, detail_dto.task.to_model)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.agricultural_tasks_path
        end
      end
    end
  end
end