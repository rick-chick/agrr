# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestHtmlNewMasterFormHtmlPresenter < Domain::Pest::Ports::PestHtmlNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(state)
          @view.instance_variable_set(:@pest, state.pest)
          @view.instance_variable_set(:@crop_cards, state.crop_cards)
          @view.instance_variable_set(:@selected_crop_ids, state.selected_crop_ids)
        end
      end
    end
  end
end
