# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideEditFormPickListsHtmlPresenter < Domain::Pesticide::Ports::PesticideEditFormPickListsOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pick_list_bundle)
          @view.instance_variable_set(:@crops, pick_list_bundle.crop_pick_rows)
          @view.instance_variable_set(:@pests, pick_list_bundle.pest_pick_rows)
        end
      end
    end
  end
end
