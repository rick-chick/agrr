# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      class FarmNewMasterFormHtmlPresenter < Domain::Farm::Ports::FarmNewMasterFormOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@farm, Forms::FarmMasterForm.from_snapshot(master_form_snapshot))
          assign_new_master_form_html_display(@view)
        end
      end
    end
  end
end
