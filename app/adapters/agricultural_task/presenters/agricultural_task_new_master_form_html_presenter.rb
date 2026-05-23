# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskNewMasterFormHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(task_for_form)
          @view.instance_variable_set(:@agricultural_task, task_for_form)
        end
      end
    end
  end
end
