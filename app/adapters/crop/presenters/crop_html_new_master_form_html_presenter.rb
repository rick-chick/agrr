# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropHtmlNewMasterFormHtmlPresenter < Domain::Crop::Ports::CropHtmlNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        # @param master_form_snapshot [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@crop, Forms::CropMasterForm.from_snapshot(master_form_snapshot))
        end
      end
    end
  end
end
