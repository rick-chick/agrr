# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDetailHtmlPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        # farm_detail_view_for: FarmDetailOutputDto -> { farm: AR::Farm, fields: Array<AR::Field> }
        def initialize(view:, farm_detail_view_for:)
          @view = view
          @farm_detail_view_for = farm_detail_view_for
        end

        def on_success(farm_detail_dto)
          view_models = @farm_detail_view_for.call(farm_detail_dto)
          @view.instance_variable_set(:@farm, view_models[:farm])
          @view.instance_variable_set(:@fields, view_models[:fields])
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.farms_path
        end
      end
    end
  end
end
