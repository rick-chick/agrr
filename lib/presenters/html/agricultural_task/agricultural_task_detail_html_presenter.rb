# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskDetailHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailOutputPort
        def initialize(view:, agricultural_task_record_for_detail_dto:)
          @view = view
          @agricultural_task_record_for_detail_dto = agricultural_task_record_for_detail_dto
        end

        def on_success(detail_dto)
          @view.instance_variable_set(
            :@agricultural_task,
            @agricultural_task_record_for_detail_dto.call(detail_dto)
          )
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.agricultural_tasks_path
        end
      end
    end
  end
end
