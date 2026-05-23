# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideNewMasterFormHtmlPresenter < Domain::Pesticide::Ports::PesticideNewMasterFormOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@pesticide, Forms::PesticideMasterForm.from_snapshot(bundle.pesticide_master_form_snapshot))
          @view.instance_variable_set(:@crops, bundle.crop_pick_rows)
          @view.instance_variable_set(:@pests, bundle.pest_pick_rows)
          assign_new_master_form_html_display(@view)
        end
      end
    end
  end
end
