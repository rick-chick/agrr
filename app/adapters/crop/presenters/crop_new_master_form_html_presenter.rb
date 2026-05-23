# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropNewMasterFormHtmlPresenter < Domain::Crop::Ports::CropNewMasterFormOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        # @param master_form_snapshot [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@crop, Forms::CropMasterForm.from_snapshot(master_form_snapshot))
          assign_new_master_form_html_display(@view)
        end
      end
    end
  end
end
