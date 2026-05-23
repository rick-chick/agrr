# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskUpdateFormSnapshotHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateFormSnapshotOutputPort
        def initialize(view:)
          @view = view
        end

        def on_apply(task_for_form:, selected_crop_ids:, crop_cards:)
          @view.instance_variable_set(:@agricultural_task, task_for_form)
          @view.instance_variable_set(:@selected_crop_ids, selected_crop_ids)
          @view.instance_variable_set(:@crop_cards, crop_cards)
        end
      end
    end
  end
end
