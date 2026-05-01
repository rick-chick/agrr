# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmListHtmlPresenter < Domain::Farm::Ports::FarmListHtmlOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(success_dto)
          @view.instance_variable_set(:@farms, success_dto.farm_rows)
          @view.instance_variable_set(:@reference_farms, success_dto.reference_farm_rows)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@farms, [])
          @view.instance_variable_set(:@reference_farms, [])
        end
      end
    end
  end
end
