# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropPestsNewHtmlPresenter
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(pest_crop_nest_snapshot:, unassociated_pests:)
          @view.instance_variable_set(:@unassociated_pests, unassociated_pests)
          @view.instance_variable_set(:@pest, Forms::CropNestedPestForm.from_crop_nest_snapshot(pest_crop_nest_snapshot))
          assign_new_master_form_html_display(@view)
        end

        def render_template
          @view.render_form(:new)
        end
      end
    end
  end
end
