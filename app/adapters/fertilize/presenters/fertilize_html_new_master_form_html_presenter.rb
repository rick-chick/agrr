# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      class FertilizeHtmlNewMasterFormHtmlPresenter < Domain::Fertilize::Ports::FertilizeHtmlNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@fertilize, Forms::FertilizeMasterForm.from_snapshot(master_form_snapshot))
        end
      end
    end
  end
end
