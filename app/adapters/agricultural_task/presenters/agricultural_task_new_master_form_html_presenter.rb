# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskNewMasterFormHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskNewMasterFormOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(task_for_form)
          @view.instance_variable_set(:@agricultural_task, task_for_form)
          assign_new_master_form_html_display(@view)
        end
      end
    end
  end
end
