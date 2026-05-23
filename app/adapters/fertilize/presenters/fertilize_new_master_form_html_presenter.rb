# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      class FertilizeNewMasterFormHtmlPresenter < Domain::Fertilize::Ports::FertilizeNewMasterFormOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@fertilize, Forms::FertilizeMasterForm.from_snapshot(master_form_snapshot))
          assign_new_master_form_html_display(@view)
        end
      end
    end
  end
end
