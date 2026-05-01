# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskListHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskListOutputPort
        # @reference_farms は既存ビュー／rescue 互換の ivar 名（参照農作業エンティティの配列）
        def initialize(view:, input_dto: nil)
          @view = view
          @input_dto = input_dto || Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.new(is_admin: false)
        end

        def on_success(tasks, reference_tasks_for_index: [])
          @view.instance_variable_set(:@agricultural_tasks, tasks)
          @view.instance_variable_set(:@query, @input_dto.query.to_s)
          @view.instance_variable_set(:@selected_filter, @input_dto.filter.to_s)

          @view.instance_variable_set(:@reference_farms, reference_tasks_for_index)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@agricultural_tasks, [])
          @view.instance_variable_set(:@reference_farms, [])
        end
      end
    end
  end
end
