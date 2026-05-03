# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDetailHtmlPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_detail_dto)
          @view.instance_variable_set(:@farm, farm_detail_dto.farm)
          @view.instance_variable_set(:@fields, farm_detail_dto.fields)
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("farms.flash.no_permission")
            @view.redirect_to @view.farms_path
            return
          end

          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.farms_path
        end
      end
    end
  end
end
