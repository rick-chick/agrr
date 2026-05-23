# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      class FarmNewMasterFormHtmlPresenter < Domain::Farm::Ports::FarmNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@farm, Forms::FarmMasterForm.from_snapshot(master_form_snapshot))
        end
      end
    end
  end
end
