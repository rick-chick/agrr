# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskListHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskListOutputPort
        def initialize(view:, input_dto: nil)
          @view = view
          @input_dto = input_dto || Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.new(is_admin: false)
        end

        def on_success(tasks)
          @view.instance_variable_set(:@agricultural_tasks, tasks.map(&:to_model))
          @view.instance_variable_set(:@query, @input_dto.query.to_s)
          @view.instance_variable_set(:@selected_filter, @input_dto.filter.to_s)

          # reference_farms は admin のみ設定
          reference_farms = @input_dto.is_admin ? ::AgriculturalTask.where(is_reference: true) : []
          @view.instance_variable_set(:@reference_farms, reference_farms)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@agricultural_tasks, [])
        end
      end
    end
  end
end